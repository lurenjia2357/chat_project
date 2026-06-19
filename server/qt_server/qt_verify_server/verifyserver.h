#ifndef VERIFYSERVER_H
#define VERIFYSERVER_H

#include <QObject>
#include <QHttpServer>
#include <QMap>
#include <QDateTime>
#include <QMutex>

class VerifyServer : public QObject
{
    Q_OBJECT
public:
    explicit VerifyServer(QObject *parent = nullptr);
    bool start(quint16 port = 10086);

private:
    bool verifyCode(const QString &email, const QString &code);
    void sendVerifyMail(const QString &email, const QString &code);

    // 清晰、各司其职的数据结构
    struct CodeData {
        QString code;
        QDateTime expireTime;   // 验证码过期时间（5分钟）
        QDateTime lastSendTime; // 上次发送时间（30秒限流）
    };

    QHttpServer *m_httpServer = nullptr;
    QMap<QString, CodeData> m_codes;
    QMutex m_mutex;

    const QString m_from = "";
    const QString m_password  = "";
};

#endif // VERIFYSERVER_H
