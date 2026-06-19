#ifndef SMTPCLIENT_H
#define SMTPCLIENT_H

#include <QObject>
#include <QSslSocket>

class SmtpClient : public QObject
{
    Q_OBJECT
public:
    explicit SmtpClient(QObject *parent = nullptr);
    ~SmtpClient();

    void sendEmail(const QString &from, const QString &password,
                  const QString &to, const QString &subject, const QString &body);

signals:
    void sigSmtpFinished(bool success, const QString &error);

private slots:
    void onReadyRead();
    void onError(QAbstractSocket::SocketError error);

private:
    void sendCommand(const QByteArray &cmd);
    int m_state = 0;
    QSslSocket *m_socket = nullptr;
    QString m_from, m_password, m_to, m_subject, m_body;
    bool m_finished = false;
};

#endif // SMTPCLIENT_H
