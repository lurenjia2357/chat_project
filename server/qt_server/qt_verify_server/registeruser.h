#ifndef REGISTERUSER_H
#define REGISTERUSER_H

#include <QString>
#include <QJsonArray>

class RegisterUser
{
public:
    static RegisterUser& instance();
    bool connect(const QString &host, int port, const QString &dbName, const QString &user, const QString &password);
    bool insertUser(const QString &username, const QString &email, const QString &password);
    bool updatePassword(const QString &email, const QString &newPassword);
    int verifyLogin(const QString &username, const QString &password, QString &outAvatar, QString &outEmail);
    QJsonArray getFriendList(int userId);
    QJsonArray searchUser(const QString &keyword, int excludeUserId);
    bool addFriend(int userId, int friendId);
    int getPendingRequestCount(int userId);
    QJsonArray getPendingRequests(int userId);
    bool acceptFriend(int fromUserId, int toUserId);
    bool rejectFriend(int fromUserId, int toUserId);

private:
    RegisterUser() = default;
};

#endif // REGISTERUSER_H
