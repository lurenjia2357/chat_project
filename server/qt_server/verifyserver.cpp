#include "verifyserver.h"
#include "smtpclient.h"
#include "sqlmanager.h"
#include "chatserver.h"
#include <QRandomGenerator>
#include <QDebug>
#include <QUrlQuery>
#include <QTcpServer>
#include <QMutexLocker>
#include <QTimer>
#include <QPointer>
#include <QUrl>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QSqlDatabase>
#include <QSqlQuery>

using Status = QHttpServerResponder::StatusCode;

VerifyServer::VerifyServer(QObject *parent) : QObject(parent)
{
    m_httpServer = new QHttpServer(this);

    // 建立针对自身的弱引用指针，用于 Lambda 捕获，彻底解决多线程异步时序的 Clang 警告
    QPointer<VerifyServer> weakThis(this);

    // 1. POST /send_email
    m_httpServer->route("/send_email", QHttpServerRequest::Method::Post, this, [weakThis](const QHttpServerRequest &req) {
        if (weakThis.isNull()) return QHttpServerResponse("服务器错误", Status::InternalServerError);

        QString email = QString::fromUtf8(req.body()).trimmed();
        if (email.isEmpty()) return QHttpServerResponse("邮件丢失", Status::BadRequest);

        auto now = QDateTime::currentDateTime();
        QMutexLocker locker(&weakThis->m_mutex);

        // 直观清晰的 30 秒重发限流判断
        if (weakThis->m_codes.contains(email)) {
            if (now < weakThis->m_codes[email].lastSendTime.addSecs(30)) {
                return QHttpServerResponse("请等待", Status::TooManyRequests);
            }
        }

        // 生成 100000 ~ 999999 的 6 位随机验证码
        QString code = QString::number(QRandomGenerator::global()->bounded(100000, 1000000));

        // 显式更新对应的时间戳
        auto &data = weakThis->m_codes[email];
        data.code = code;
        data.lastSendTime = now;         // 判定重发限制
        data.expireTime = now.addSecs(300); // 5分钟有效时间

        weakThis->sendVerifyMail(email, code);
        return QHttpServerResponse("成功", Status::Accepted);
    });

    // 2. POST /verify_code
    m_httpServer->route("/verify_code", QHttpServerRequest::Method::Post, this, [weakThis](const QHttpServerRequest &req) {
        if (weakThis.isNull()) return QHttpServerResponse("服务器错误", Status::InternalServerError);

        QUrlQuery query(QString::fromUtf8(req.body()).trimmed());
        QString email = query.queryItemValue("email"), code = query.queryItemValue("code");

        if (email.isEmpty() || code.isEmpty()) return QHttpServerResponse("邮件或验证码丢失", Status::BadRequest);
        return QHttpServerResponse(weakThis->verifyCode(email, code) ? "OK" : "FAIL");
    });

    // 3. 定时清理
    auto timer = new QTimer(this);
    connect(timer, &QTimer::timeout, this, [weakThis]() {
        if (weakThis.isNull()) return;
        QMutexLocker locker(&weakThis->m_mutex);
        auto now = QDateTime::currentDateTime();

        for (auto it = weakThis->m_codes.begin(); it != weakThis->m_codes.end(); ) {
            // 条件1：正常的 5 分钟验证码过期
            // 条件2：发送满 1 小时未被更新的僵尸数据（极其罕见的网络异常兜底）
            if (it->expireTime < now || it->lastSendTime.addSecs(3600) < now) {
                it = weakThis->m_codes.erase(it);
            } else {
                ++it;
            }
        }
    });

    timer->start(60000); // 每 60 秒轮询清理一次

    m_httpServer->route("/register_user", QHttpServerRequest::Method::Post, this, [weakThis](const QHttpServerRequest &req) {
        if (weakThis.isNull()){
            return QHttpServerResponse("服务器错误", Status::InternalServerError);
        }

        QUrlQuery query(QString::fromUtf8(req.body()).trimmed());
        QString username = QUrl::fromPercentEncoding(query.queryItemValue("username").toUtf8());
        QString email = QUrl::fromPercentEncoding(query.queryItemValue("email").toUtf8());
        QString password = QUrl::fromPercentEncoding(query.queryItemValue("password").toUtf8());
        QString code = QUrl::fromPercentEncoding(query.queryItemValue("code").toUtf8());

        if (username.isEmpty() || email.isEmpty() || password.isEmpty() || code.isEmpty()) {
            return QHttpServerResponse("参数缺失", Status::BadRequest);
        }

        if (!weakThis->verifyCode(email, code)) {
            return QHttpServerResponse("验证码错误或已过期", Status::Unauthorized);
        }

        if (SqlManager::instance().insertUser(username, email, password)) {
            return QHttpServerResponse("注册成功", Status::Ok);
        } else {
            return QHttpServerResponse("注册失败，用户名或邮箱已存在", Status::Conflict);
        }
    });

    m_httpServer->route("/reset_password", QHttpServerRequest::Method::Post, this, [weakThis](const QHttpServerRequest& req) {
        if (weakThis.isNull()){
            return QHttpServerResponse("服务器错误", Status::InternalServerError);
        }

        QUrlQuery query(QString::fromUtf8(req.body()).trimmed());
        QString email = QUrl::fromPercentEncoding(query.queryItemValue("email").toUtf8());
        QString password = QUrl::fromPercentEncoding(query.queryItemValue("password").toUtf8());
        QString code = QUrl::fromPercentEncoding(query.queryItemValue("code").toUtf8());

        if (email.isEmpty() || password.isEmpty() || code.isEmpty()) {
            return QHttpServerResponse("参数缺失", Status::BadRequest);
        }

        if (!weakThis->verifyCode(email, code)) {
            return QHttpServerResponse("验证码错误或已过期", Status::Unauthorized);
        }

        if (SqlManager::instance().updatePassword(email, password)) {
            return QHttpServerResponse("密码重置成功", Status::Ok);
        } else {
            return QHttpServerResponse("密码重置失败，邮箱未注册", Status::Conflict);
        }
    });

    m_httpServer->route("/login", QHttpServerRequest::Method::Post, this, [weakThis](const QHttpServerRequest &req) {
        if (weakThis.isNull()) {
            return QHttpServerResponse("服务器错误", Status::InternalServerError);
        }

        QUrlQuery query(QString::fromUtf8(req.body()).trimmed());
        QString username = QUrl::fromPercentEncoding(query.queryItemValue("username").toUtf8());
        QString password = QUrl::fromPercentEncoding(query.queryItemValue("password").toUtf8());

        if (username.isEmpty() || password.isEmpty()) {
            return QHttpServerResponse("用户名或密码不能为空", Status::BadRequest);
        }

        QString avatar;
        QString email;

        int userId = SqlManager::instance().verifyLogin(username, password, avatar, email);

        if (userId < 0) {
            return QHttpServerResponse("用户名或密码错误", Status::Unauthorized);
        }

        QJsonObject resp;
        resp["user_id"] = userId;
        resp["username"] = username;
        resp["avatar"] = avatar;
        resp["email"] = email;

        return QHttpServerResponse("application/json",
                                   QJsonDocument(resp).toJson(QJsonDocument::Compact),
                                   Status::Ok);
    });

    // 获取好友列表
    m_httpServer->route("/friend_list", QHttpServerRequest::Method::Get, this, [weakThis](const QHttpServerRequest &req) {
        if (weakThis.isNull()) {
            return QHttpServerResponse("服务器错误", Status::InternalServerError);
        }

        QUrlQuery query(req.query());
        QString userIdStr = query.queryItemValue("user_id");

        if (userIdStr.isEmpty()) {
            return QHttpServerResponse("缺少 user_id", Status::BadRequest);
        }
        int userId = userIdStr.toInt();
        QJsonArray list = SqlManager::instance().getFriendList(userId);

        return QHttpServerResponse("application/json",
                                   QJsonDocument(list).toJson(QJsonDocument::Compact),
                                   Status::Ok);
    });

    m_httpServer->route("/update_avatar", QHttpServerRequest::Method::Post, this, [weakThis](const QHttpServerRequest &req) {
        if (weakThis.isNull()) {
            return QHttpServerResponse(Status::InternalServerError);
        }

        QUrlQuery query(QString::fromUtf8(req.body()).trimmed());
        QString userIdStr = query.queryItemValue("user_id");
        QString avatar = QUrl::fromPercentEncoding(query.queryItemValue("avatar").toUtf8());

        if (userIdStr.isEmpty() || avatar.isEmpty()) {
            return QHttpServerResponse(Status::BadRequest);
        }

        int userId = userIdStr.toInt();
        QSqlDatabase db = QSqlDatabase::database();
        QSqlQuery q(db);
        q.prepare("UPDATE user SET avatar = ? WHERE id = ?");
        q.addBindValue(avatar);
        q.addBindValue(userId);

        return q.exec() ? QHttpServerResponse(Status::Ok) : QHttpServerResponse(Status::InternalServerError);
    });

    m_httpServer->route("/search_user", QHttpServerRequest::Method::Get, this, [weakThis](const QHttpServerRequest &req) {
        if (weakThis.isNull()) {
            return QHttpServerResponse("服务器错误", Status::InternalServerError);
        }

        QUrlQuery query(req.query());
        QString keyword = query.queryItemValue("keyword");
        QString userIdStr = query.queryItemValue("user_id");

        if (keyword.isEmpty() || userIdStr.isEmpty()) {
            return QHttpServerResponse("参数缺失", Status::BadRequest);
        }

        int userId = userIdStr.toInt();
        QJsonArray list = SqlManager::instance().searchUser(keyword, userId);

        return QHttpServerResponse("application/json",
                                   QJsonDocument(list).toJson(QJsonDocument::Compact),
                                   Status::Ok);
    });


    m_httpServer->route("/add_friend", QHttpServerRequest::Method::Post, this, [weakThis](const QHttpServerRequest &req) {
        if (weakThis.isNull()) {
            return QHttpServerResponse(Status::InternalServerError);
        }

        QUrlQuery query(QString::fromUtf8(req.body()).trimmed());
        QString userIdStr = query.queryItemValue("user_id");
        QString friendIdStr = query.queryItemValue("friend_id");

        if (userIdStr.isEmpty() || friendIdStr.isEmpty()) {
            return QHttpServerResponse(Status::BadRequest);
        }

        int userId = userIdStr.toInt();
        int friendId = friendIdStr.toInt();

        if (SqlManager::instance().addFriend(userId, friendId)) {
            return QHttpServerResponse(Status::Created);
        }else {
            return QHttpServerResponse(Status::Conflict);
        }
    });

    m_httpServer->route("/pending_count", QHttpServerRequest::Method::Get, this, [weakThis](const QHttpServerRequest &req) {
        if (weakThis.isNull()) {
            return QHttpServerResponse(Status::InternalServerError);
        }

        QUrlQuery query(req.query());
        QString userIdStr = query.queryItemValue("user_id");

        if (userIdStr.isEmpty()) {
            return QHttpServerResponse(Status::BadRequest);
        }

        int userId = userIdStr.toInt();
        int count = SqlManager::instance().getPendingRequestCount(userId);

        QJsonObject resp;
        resp["count"] = count;

        return QHttpServerResponse("application/json",
                                   QJsonDocument(resp).toJson(QJsonDocument::Compact),
                                   Status::Ok);
    });

    m_httpServer->route("/pending_requests", QHttpServerRequest::Method::Get, this, [weakThis](const QHttpServerRequest &req) {
        if (weakThis.isNull()) {
            return QHttpServerResponse(Status::InternalServerError);
        }

        QUrlQuery query(req.query());
        QString userIdStr = query.queryItemValue("user_id");
        if (userIdStr.isEmpty()) {
            return QHttpServerResponse(Status::BadRequest);
        }

        int userId = userIdStr.toInt();
        QJsonArray list = SqlManager::instance().getPendingRequests(userId);

        return QHttpServerResponse("application/json",
                                   QJsonDocument(list).toJson(QJsonDocument::Compact),
                                   Status::Ok);
    });

    m_httpServer->route("/accept_friend", QHttpServerRequest::Method::Post, this, [weakThis](const QHttpServerRequest &req) {
        if (weakThis.isNull()) {
            return QHttpServerResponse(Status::InternalServerError);
        }

        QUrlQuery query(QString::fromUtf8(req.body()).trimmed());
        int fromUserId = query.queryItemValue("from_user_id").toInt();
        int toUserId = query.queryItemValue("to_user_id").toInt();

        if (SqlManager::instance().acceptFriend(fromUserId, toUserId)) {
            return QHttpServerResponse(Status::Ok);
        } else {
            return QHttpServerResponse(Status::Conflict);
        }
    });

    m_httpServer->route("/reject_friend", QHttpServerRequest::Method::Post, this, [weakThis](const QHttpServerRequest &req) {
        if (weakThis.isNull()) {
            return QHttpServerResponse(Status::InternalServerError);
        }

        QUrlQuery query(QString::fromUtf8(req.body()).trimmed());
        int fromUserId = query.queryItemValue("from_user_id").toInt();
        int toUserId = query.queryItemValue("to_user_id").toInt();

        SqlManager::instance().rejectFriend(fromUserId, toUserId);
        return QHttpServerResponse(Status::Ok);
    });

    m_httpServer->route("/send_message", QHttpServerRequest::Method::Post, this, [weakThis](const QHttpServerRequest &req) {
        if (weakThis.isNull()) {
            return QHttpServerResponse(Status::InternalServerError);
        }

        QUrlQuery query(QString::fromUtf8(req.body()).trimmed());
        int fromUserId = query.queryItemValue("from_user_id").toInt();
        int toUserId   = query.queryItemValue("to_user_id").toInt();
        QString content = QUrl::fromPercentEncoding(query.queryItemValue("content").toUtf8());

        if (fromUserId <= 0 || toUserId <= 0 || content.isEmpty()) {
            return QHttpServerResponse(Status::BadRequest);
        }

        qint64 msgId = ChatServer::instance().sendMessage(fromUserId, toUserId, content);
        if (msgId > 0) {
            QJsonObject resp;
            resp["id"] = msgId;
            return QHttpServerResponse("application/json",
                                       QJsonDocument(resp).toJson(QJsonDocument::Compact),
                                       Status::Ok);
        } else {
            return QHttpServerResponse(Status::Forbidden);
        }
    });

    m_httpServer->route("/get_messages", QHttpServerRequest::Method::Get, this, [weakThis](const QHttpServerRequest &req) {
        if (weakThis.isNull()) {
            return QHttpServerResponse(Status::InternalServerError);
        }

        QUrlQuery query(req.query());
        int userId   = query.queryItemValue("user_id").toInt();
        int friendId = query.queryItemValue("friend_id").toInt();
        qint64 afterId = query.queryItemValue("after_id").toLongLong();
        int limit = query.queryItemValue("limit").toInt();

        if (limit <= 0) limit = 100;

        if (userId <= 0) {
            return QHttpServerResponse(Status::BadRequest);
        }

        QJsonArray arr = ChatServer::instance().getMessages(userId, friendId, afterId, limit);

        return QHttpServerResponse("application/json",
                                   QJsonDocument(arr).toJson(QJsonDocument::Compact),
                                   Status::Ok);
    });

    // 拉取对话列表
    m_httpServer->route("/conversations", QHttpServerRequest::Method::Get, this, [weakThis](const QHttpServerRequest &req) {
        if (weakThis.isNull()) {
            return QHttpServerResponse("服务器错误", Status::InternalServerError);
        }

        QUrlQuery query(req.query());
        int userId = query.queryItemValue("user_id").toInt();

        if (userId <= 0) {
            return QHttpServerResponse("缺少 user_id", Status::BadRequest);
        }

        QJsonArray arr = ChatServer::instance().getConversations(userId);
        return QHttpServerResponse("application/json",
                                   QJsonDocument(arr).toJson(QJsonDocument::Compact),
                                   Status::Ok);
    });

    // 标记对话已读
    m_httpServer->route("/mark_read", QHttpServerRequest::Method::Post, this, [weakThis](const QHttpServerRequest &req) {
        if (weakThis.isNull()) {
            return QHttpServerResponse("服务器错误", Status::InternalServerError);
        }

        QUrlQuery query(QString::fromUtf8(req.body()).trimmed());
        int userId   = query.queryItemValue("user_id").toInt();
        int friendId = query.queryItemValue("friend_id").toInt();

        if (userId <= 0 || friendId <= 0) {
            return QHttpServerResponse("参数缺失", Status::BadRequest);
        }

        ChatServer::instance().markConversationRead(userId, friendId);
        return QHttpServerResponse(Status::Ok);
    });
}

bool VerifyServer::start(quint16 port)
{
    auto tcpServer = new QTcpServer(this);
    if (!tcpServer->listen(QHostAddress::Any, port) || !m_httpServer->bind(tcpServer)) {
        qDebug() << "服务器启动失败，监听端口失败。";
        tcpServer->deleteLater();
        return false;
    }
    qDebug() << "验证码服务器已成功启动，监听端口：" << port;
    return true;
}

bool VerifyServer::verifyCode(const QString &email, const QString &code)
{
    QMutexLocker locker(&m_mutex);
    auto it = m_codes.find(email);

    qDebug() << "[verifyCode] 查询email:" << email << "code:" << code
             << "当前内存中的键:" << m_codes.keys();

    // 检查是否存在以及是否超时
    if (it == m_codes.end() || QDateTime::currentDateTime() > it->expireTime) {
        if (it != m_codes.end()) m_codes.erase(it);
        return false;
    }

    // 验证成功后，立即从内存抹除该码（一次性原则，严防暴力破解）
    return (it->code == code) ? (m_codes.erase(it), true) : false;
}

void VerifyServer::sendVerifyMail(const QString &email, const QString &code)
{
    auto smtp = new SmtpClient(this);
    QPointer<VerifyServer> weakThis(this);

    connect(smtp, &SmtpClient::sigSmtpFinished, this, [weakThis, smtp, email](bool success, const QString &error) {
        smtp->deleteLater(); // 无论成败，及时销毁 SMTP 客户端对象
        if (weakThis.isNull()) return;

        // 只要涉及 weakThis 内部容器的操作，进来第一时间必须先无条件上锁！
        QMutexLocker locker(&weakThis->m_mutex);

        if (!success) {
            qDebug() << "邮件实际投递失败，正从内存回滚并清理该验证码：" << error;
            weakThis->m_codes.remove(email); // 投递失败直接回滚抹除，允许用户立刻重发
        } else {
            qDebug() << "验证码已被 163 SMTP 服务器接收，目标邮箱：" << email;
        }
    });

    smtp->sendEmail(m_from, m_password, email, "Chat 验证码", "您的验证码是: " + code + "，5分钟内有效。");
}