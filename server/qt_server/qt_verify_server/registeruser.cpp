#include "registeruser.h"
#include <QSqlDatabase>
#include <QSqlQuery>
#include <QSqlError>
#include <QDebug>
#include <QJsonObject>

RegisterUser& RegisterUser::instance()
{
    static RegisterUser ru;
    return ru;
}

bool RegisterUser::connect(const QString &host, int port,
                           const QString &dbName, const QString &user, const QString &password)
{
    QSqlDatabase db = QSqlDatabase::addDatabase("QODBC");

    QString connStr = QString(
                          "DRIVER={MySQL ODBC 9.7 Unicode Driver};"
                          "SERVER=%1;PORT=%2;DATABASE=%3;USER=%4;PASSWORD=%5;"
                          ).arg(host, QString::number(port), dbName, user, password);

    db.setDatabaseName(connStr);

    if (!db.open()) {
        qDebug() << "数据库连接失败:" << db.lastError().text();
        return false;
    }
    qDebug() << "数据库连接成功:" << host << ":" << port;
    return true;
}

bool RegisterUser::insertUser(const QString &username, const QString &email,
                              const QString &password)
{
    QSqlDatabase db = QSqlDatabase::database();
    QSqlQuery query(db);
    qDebug() << "收到的参数:" << username << email << password;
    query.prepare("INSERT INTO user (username, email, password, avatar) VALUES (?, ?, ?, 'default_avatar')");
    query.addBindValue(username);
    query.addBindValue(email);
    query.addBindValue(password);

    if (!query.exec()) {
        qDebug() << "插入用户失败:" << query.lastError().text();
        return false;
    }

    return true;
}

bool RegisterUser::updatePassword(const QString &email, const QString &newPassword)
{
    QSqlDatabase db = QSqlDatabase::database();
    QSqlQuery query(db);

    // 先查邮箱是否存在
    query.prepare("SELECT COUNT(*) FROM user WHERE email = ?");
    query.addBindValue(email);
    if (!query.exec() || !query.next() || query.value(0).toInt() == 0) {
        qDebug() << "未找到该邮箱对应的用户:" << email;
        return false;
    }

    // 存在则更新
    query.prepare("UPDATE user SET password = ? WHERE email = ?");
    query.addBindValue(newPassword);
    query.addBindValue(email);

    if (!query.exec()) {
        qDebug() << "更新密码失败:" << query.lastError().text();
        return false;
    }

    qDebug() << "密码重置成功，邮箱:" << email;
    return true;
}

int RegisterUser::verifyLogin(const QString &username, const QString &password, QString &outAvatar, QString &outEmail)
{
    QSqlDatabase db = QSqlDatabase::database();
    QSqlQuery query(db);

    query.prepare("SELECT id, avatar, email FROM user WHERE username = ? AND password = ?");
    query.addBindValue(username);
    query.addBindValue(password);

    if (!query.exec() || !query.next()) {
        qDebug() << "登录失败：用户名或密码错误";
        return -1;
    }

    int userId = query.value(0).toInt();
    outAvatar = query.value(1).toString();
    outEmail = query.value(2).toString();
    qDebug() << "登录成功，user_id:" << userId << "avatar:" << outAvatar;
    return userId;
}

QJsonArray RegisterUser::getFriendList(int userId)
{
    QSqlDatabase db = QSqlDatabase::database();
    QSqlQuery query(db);
    QJsonArray arr;

    // 双向查询：我发起的 + 我接收的，只查已接受(status=1)的好友
    query.prepare(
        "SELECT u.id, u.username, u.avatar FROM user u "
        "INNER JOIN friend_relation fr ON "
        "  (fr.user_id = ? AND fr.friend_id = u.id) OR "
        "  (fr.friend_id = ? AND fr.user_id = u.id) "
        "WHERE fr.status = 1"
        );

    query.addBindValue(userId);
    query.addBindValue(userId);

    if (!query.exec()) {
        qDebug() << "查询好友列表失败:" << query.lastError().text();
        return arr;
    }

    while (query.next()) {
        QJsonObject obj;
        obj["user_id"] = query.value(0).toInt();
        obj["username"] = query.value(1).toString();
        obj["avatar"] = query.value(2).toString();
        arr.append(obj);
    }

    return arr;
}

QJsonArray RegisterUser::searchUser(const QString &keyword, int excludeUserId)
{
    QSqlDatabase db = QSqlDatabase::database();
    QSqlQuery query(db);
    QJsonArray arr;

    // 搜用户名或邮箱，排除自己，排除已是好友的
    query.prepare(
        "SELECT u.id, u.username, u.avatar FROM user u "
        "WHERE u.id != ? "
        "  AND (u.username LIKE ? OR u.email LIKE ?) "
        "  AND u.id NOT IN ("
        "    SELECT fr.friend_id FROM friend_relation fr WHERE fr.user_id = ? AND fr.status = 1 "
        "    UNION "
        "    SELECT fr.user_id FROM friend_relation fr WHERE fr.friend_id = ? AND fr.status = 1"
        "  )"
        );
    query.addBindValue(excludeUserId);
    query.addBindValue("%" + keyword + "%");
    query.addBindValue("%" + keyword + "%");
    query.addBindValue(excludeUserId);
    query.addBindValue(excludeUserId);

    if (!query.exec()) {
        qDebug() << "搜索用户失败:" << query.lastError().text();
        return arr;
    }

    while (query.next()) {
        QJsonObject obj;
        obj["user_id"] = query.value(0).toInt();
        obj["username"] = query.value(1).toString();
        obj["avatar"] = query.value(2).toString();
        arr.append(obj);
    }

    return arr;
}

bool RegisterUser::addFriend(int userId, int friendId)
{
    QSqlDatabase db = QSqlDatabase::database();
    QSqlQuery query(db);

    // 只检查是否已有待处理的申请（status = 0）
    query.prepare(
        "SELECT COUNT(*) FROM friend_relation "
        "WHERE ((user_id = ? AND friend_id = ?) OR (user_id = ? AND friend_id = ?)) AND status = 0"
        );
    query.addBindValue(userId);
    query.addBindValue(friendId);
    query.addBindValue(friendId);
    query.addBindValue(userId);

    if (query.exec() && query.next() && query.value(0).toInt() > 0) {
        return false;
    }

    // 插入申请
    query.prepare("INSERT INTO friend_relation (user_id, friend_id, status) VALUES (?, ?, 0)");
    query.addBindValue(userId);
    query.addBindValue(friendId);

    return query.exec();
}

int RegisterUser::getPendingRequestCount(int userId)
{
    QSqlDatabase db = QSqlDatabase::database();
    QSqlQuery query(db);

    query.prepare(
        "SELECT COUNT(*) FROM friend_relation "
        "WHERE friend_id = ? AND status = 0"
        );

    query.addBindValue(userId);

    if (query.exec() && query.next()) {
        return query.value(0).toInt();
    }

    return 0;
}

QJsonArray RegisterUser::getPendingRequests(int userId)
{
    QSqlDatabase db = QSqlDatabase::database();
    QSqlQuery query(db);
    QJsonArray arr;

    query.prepare(
        "SELECT u.id, u.username, u.avatar FROM user u "
        "INNER JOIN friend_relation fr ON fr.user_id = u.id "
        "WHERE fr.friend_id = ? AND fr.status = 0"
        );
    query.addBindValue(userId);

    if (query.exec()) {
        while (query.next()) {
            QJsonObject obj;
            obj["user_id"] = query.value(0).toInt();
            obj["username"] = query.value(1).toString();
            obj["avatar"] = query.value(2).toString();
            arr.append(obj);
        }
    }
    return arr;
}

bool RegisterUser::acceptFriend(int fromUserId, int toUserId)
{
    QSqlDatabase db = QSqlDatabase::database();
    QSqlQuery query(db);
    query.prepare("UPDATE friend_relation SET status = 1 WHERE user_id = ? AND friend_id = ? AND status = 0");
    query.addBindValue(fromUserId);
    query.addBindValue(toUserId);
    return query.exec() && query.numRowsAffected() > 0;
}

bool RegisterUser::rejectFriend(int fromUserId, int toUserId)
{
    QSqlDatabase db = QSqlDatabase::database();
    QSqlQuery query(db);
    query.prepare("DELETE FROM friend_relation WHERE user_id = ? AND friend_id = ? AND status = 0");
    query.addBindValue(fromUserId);
    query.addBindValue(toUserId);
    return query.exec();
}