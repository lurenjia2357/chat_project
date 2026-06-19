#ifndef CHATSERVER_H
#define CHATSERVER_H

#include <QJsonArray>
#include <QString>

class ChatServer
{
public:
    static ChatServer& instance();

    qint64 sendMessage(int fromUserId, int toUserId, const QString &content);
    QJsonArray getMessages(int userId, int friendId, qint64 afterId = 0, int limit = 100);
    QJsonArray getConversations(int userId);
    void markConversationRead(int userId, int friendId);

private:
    ChatServer() = default;
    void upsertConversation(int userId, int friendId, qint64 lastReadId);
};

#endif // CHATSERVER_H
