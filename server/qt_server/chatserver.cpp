#include "chatserver.h"
#include <QSqlDatabase>
#include <QSqlQuery>
#include <QSqlError>
#include <QJsonObject>
#include <QDebug>

ChatServer& ChatServer::instance()
{
    static ChatServer cs;
    return cs;
}

qint64 ChatServer::sendMessage(int fromUserId, int toUserId, const QString &content)
{
    QSqlDatabase db = QSqlDatabase::database();
    QSqlQuery query(db);

    query.prepare(
        "SELECT COUNT(*) FROM friend_relation "
        "WHERE status = 1 AND ("
        "  (user_id = ? AND friend_id = ?) OR "
        "  (user_id = ? AND friend_id = ?)"
        ")"
        );
    query.addBindValue(fromUserId);
    query.addBindValue(toUserId);
    query.addBindValue(toUserId);
    query.addBindValue(fromUserId);

    if (!query.exec() || !query.next() || query.value(0).toInt() == 0) {
        qDebug() << "[sendMessage] 非好友，拒绝:" << fromUserId << "->" << toUserId;
        return 0;
    }

    query.prepare("INSERT INTO chat_message (from_user_id, to_user_id, content) VALUES (?, ?, ?)");
    query.addBindValue(fromUserId);
    query.addBindValue(toUserId);
    query.addBindValue(content);

    if (!query.exec()) {
        qDebug() << "[sendMessage] 插入失败:" << query.lastError().text();
        return 0;
    }

    qint64 msgId = query.lastInsertId().toLongLong();

    // 更新双方的 conversation 记录
    upsertConversation(fromUserId, toUserId, msgId);    // 发送方：已读
    upsertConversation(toUserId, fromUserId, 0);        // 接收方：未读（last_read_id 不变）

    return msgId;
}

QJsonArray ChatServer::getMessages(int userId, int friendId, qint64 afterId, int limit)
{
    QSqlDatabase db = QSqlDatabase::database();
    QSqlQuery query(db);
    QJsonArray arr;

    QString sql =
        "SELECT id, from_user_id, to_user_id, content, UNIX_TIMESTAMP(send_time) "
        "FROM chat_message "
        "WHERE ((from_user_id = ? AND to_user_id = ?) "
        "    OR (from_user_id = ? AND to_user_id = ?))";

    if (afterId > 0) {
        sql += " AND id > ?";
    }
    sql += " ORDER BY send_time LIMIT ?";

    query.prepare(sql);
    query.addBindValue(userId);
    query.addBindValue(friendId);
    query.addBindValue(friendId);
    query.addBindValue(userId);

    if (afterId > 0) {
        query.addBindValue(afterId);
    }
    query.addBindValue(limit);

    if (!query.exec()) {
        qDebug() << "[getMessages] 查询失败:" << query.lastError().text();
        return arr;
    }

    while (query.next()) {
        QJsonObject obj;
        obj["id"] = query.value(0).toLongLong();
        obj["from_user_id"] = query.value(1).toInt();
        obj["to_user_id"] = query.value(2).toInt();
        obj["content"] = query.value(3).toString();
        obj["send_time"] = query.value(4).toLongLong();
        arr.append(obj);
    }

    return arr;
}

// 更新/创建对话记录
// 如果 lastReadId > 0：说明该用户已读到此消息（发送方或主动标记已读）
// 如果 lastReadId = 0：只更新 last_time，不更新 last_read_id（保留旧值）
void ChatServer::upsertConversation(int userId, int friendId, qint64 lastReadId)
{
    QSqlDatabase db = QSqlDatabase::database();
    QSqlQuery query(db);

    if (lastReadId > 0) {
        query.prepare(
            "INSERT INTO conversation (user_id, friend_id, last_read_id, last_time) "
            "VALUES (?, ?, ?, NOW()) "
            "ON DUPLICATE KEY UPDATE "
            "  last_read_id = VALUES(last_read_id), "
            "  last_time = NOW()"
            );
        query.addBindValue(userId);
        query.addBindValue(friendId);
        query.addBindValue(lastReadId);
    } else {
        query.prepare(
            "INSERT INTO conversation (user_id, friend_id, last_read_id, last_time) "
            "VALUES (?, ?, 0, NOW()) "
            "ON DUPLICATE KEY UPDATE "
            "  last_time = NOW()"
            );
        query.addBindValue(userId);
        query.addBindValue(friendId);
    }

    if (!query.exec()) {
        qDebug() << "[upsertConversation] 失败:" << query.lastError().text();
    }
}

// 获取对话列表
QJsonArray ChatServer::getConversations(int userId)
{
    QSqlDatabase db = QSqlDatabase::database();
    QSqlQuery query(db);
    QJsonArray arr;

    query.prepare(
        "SELECT u.id, u.username, u.avatar, UNIX_TIMESTAMP(c.last_time), "
        "  (SELECT COUNT(*) FROM chat_message m "
        "   WHERE ((m.from_user_id = c.user_id AND m.to_user_id = c.friend_id) "
        "      OR (m.from_user_id = c.friend_id AND m.to_user_id = c.user_id)) "
        "     AND m.id > c.last_read_id) AS unread_count "
        "FROM conversation c "
        "INNER JOIN user u ON u.id = c.friend_id "
        "WHERE c.user_id = ? "
        "ORDER BY c.last_time DESC"
        );
    query.addBindValue(userId);

    if (!query.exec()) {
        qDebug() << "[getConversations] 查询失败:" << query.lastError().text();
        return arr;
    }

    while (query.next()) {
        QJsonObject obj;
        obj["friend_id"] = query.value(0).toInt();
        obj["username"] = query.value(1).toString();
        obj["avatar"] = query.value(2).toString();
        obj["last_time"] = query.value(3).toLongLong();
        obj["unread_count"] = query.value(4).toInt();
        arr.append(obj);
    }

    return arr;
}

// 标记对话已读
void ChatServer::markConversationRead(int userId, int friendId)
{
    QSqlDatabase db = QSqlDatabase::database();
    QSqlQuery query(db);

    query.prepare(
        "UPDATE conversation c "
        "SET c.last_read_id = ("
        "  SELECT COALESCE(MAX(m.id), c.last_read_id) FROM chat_message m "
        "  WHERE ((m.from_user_id = ? AND m.to_user_id = ?) "
        "      OR (m.from_user_id = ? AND m.to_user_id = ?))"
        ") "
        "WHERE c.user_id = ? AND c.friend_id = ?"
        );
    query.addBindValue(userId);
    query.addBindValue(friendId);
    query.addBindValue(friendId);
    query.addBindValue(userId);
    query.addBindValue(userId);
    query.addBindValue(friendId);

    if (!query.exec()) {
        qDebug() << "[markConversationRead] 失败:" << query.lastError().text();
    }
}