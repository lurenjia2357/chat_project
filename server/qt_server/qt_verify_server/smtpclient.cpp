#include "smtpclient.h"
#include <QDebug>

SmtpClient::SmtpClient(QObject *parent)
    : QObject(parent)
{
    m_socket = new QSslSocket(this);
    connect(m_socket, &QSslSocket::readyRead, this, &SmtpClient::onReadyRead);
    connect(m_socket, &QSslSocket::errorOccurred, this, &SmtpClient::onError);
}

SmtpClient::~SmtpClient()
{

}

void SmtpClient::sendEmail(const QString &from, const QString &password,
                          const QString &to, const QString &subject, const QString &body)
{
    m_from = from;
    m_password = password;
    m_to = to;
    m_subject = subject;
    m_body = body;

    m_state = 0;
    m_finished = false;

    if (m_socket->state() != QAbstractSocket::UnconnectedState) {
        m_socket->abort();
    }

    m_socket->connectToHostEncrypted("smtp.163.com", 465);
}

void SmtpClient::onReadyRead()
{
    // 如果之前已经报错/完成并释放了，后续网络残余数据一律在这里榨干并强行拦截
    if (m_finished) {
        m_socket->readAll();
        return;
    }

    QString response = QString::fromUtf8(m_socket->readAll());
    qDebug() << "[SMTP 状态机当前阶段:" << m_state << "] 收到服务器原始响应 ->" << response.trimmed();

    switch (m_state) {
    case 0:
        if (response.startsWith("220")) {
            sendCommand("EHLO localhost\r\n");
            m_state = 1;
        } else {
            m_finished = true;
            m_socket->disconnectFromHost();
            emit sigSmtpFinished(false, QString("【连接阶段失败】: 期望收到服务器就绪信号(220)。原始响应: [%1]").arg(response.trimmed()));
        }
        break;

    case 1:
        if (response.startsWith("250")) {
            sendCommand("AUTH LOGIN\r\n");
            m_state = 2;
        } else {
            m_finished = true;
            m_socket->disconnectFromHost();
            emit sigSmtpFinished(false, QString("【打招呼 EHLO 失败】: 客户端尝试发送握手指令(EHLO)，被服务器拒绝。原始响应: [%1]").arg(response.trimmed()));
        }
        break;

    case 2:
        if (response.startsWith("334")) {
            sendCommand(m_from.toUtf8().toBase64() + "\r\n");
            m_state = 3;
        } else {
            m_finished = true;
            m_socket->disconnectFromHost();
            emit sigSmtpFinished(false, QString("【认证请求失败】: 登录请求(AUTH LOGIN)被服务器拒绝。原始响应: [%1]").arg(response.trimmed()));
        }
        break;

    case 3:
        if (response.startsWith("334")) {
            sendCommand(m_password.toUtf8().toBase64() + "\r\n");
            m_state = 4;
        } else {
            m_finished = true;
            m_socket->disconnectFromHost();
            emit sigSmtpFinished(false, QString("【用户名(邮箱账号)被拒绝】: 尝试提交发送方邮箱，服务器报错。原始响应: [%1]").arg(response.trimmed()));
        }
        break;

    case 4:
        if (response.startsWith("235")) {
            sendCommand("MAIL FROM:<" + m_from.toUtf8() + ">\r\n");
            m_state = 5;
        } else {
            m_finished = true;
            m_socket->disconnectFromHost();
            emit sigSmtpFinished(false, QString("【密码/授权码认证失败】: 163 邮箱授权码验证未通过。原始响应: [%1]").arg(response.trimmed()));
        }
        break;

    case 5:
        if (response.startsWith("250")) {
            sendCommand("RCPT TO:<" + m_to.toUtf8() + ">\r\n");
            m_state = 6;
        } else {
            m_finished = true;
            m_socket->disconnectFromHost();
            emit sigSmtpFinished(false, QString("【发件人身份遭拒绝】: 服务器不接收来自 <%1> 的邮件外发请求。原始响应: [%2]").arg(m_from, response.trimmed()));
        }
        break;

    case 6:
        if (response.startsWith("250")) {
            sendCommand("DATA\r\n");
            m_state = 7;
        } else {
            m_finished = true;
            m_socket->disconnectFromHost();
            emit sigSmtpFinished(false, QString("【收件人邮箱遭拒绝】: 无法将邮件投递给 <%1>。原始响应: [%2]").arg(m_to, response.trimmed()));
        }
        break;

    case 7:
        if (response.startsWith("354")) {
            QByteArray content;
            content.append("From: " + m_from.toUtf8() + "\r\n");
            content.append("To: " + m_to.toUtf8() + "\r\n");
            if (!m_subject.isEmpty()) {
                content.append("Subject: " + m_subject.toUtf8() + "\r\n");
            }
            content.append("Content-Type: text/plain; charset=UTF-8\r\n");
            content.append("\r\n");
            content.append(m_body.toUtf8());
            content.append("\r\n.\r\n");

            sendCommand(content);
            m_state = 8;
        } else {
            m_finished = true;
            m_socket->disconnectFromHost();
            emit sigSmtpFinished(false, QString("【发送正文遭到拒绝】: 发送 DATA 指令后服务器未返回 354 开始传输信号。原始响应: [%1]").arg(response.trimmed()));
        }
        break;

    case 8:
        if (response.startsWith("250")) {
            sendCommand("QUIT\r\n");
            m_state = 9;
        } else {
            m_finished = true;
            m_socket->disconnectFromHost();
            emit sigSmtpFinished(false, QString("【邮件文本内容被 163 拦截】: 文本提交后被 163 判定为垃圾邮件或敏感内容。原始响应: [%1]").arg(response.trimmed()));
        }
        break;

    case 9:
        if (response.startsWith("221")) {
            m_socket->disconnectFromHost();
            m_finished = true;
            emit sigSmtpFinished(true, "邮件已成功投递且安全断开连接。");
        } else {
            m_finished = true;
            m_socket->disconnectFromHost();
            emit sigSmtpFinished(false, QString("【退出 QUIT 异常】: 告别时未得到标准回应(221)。原始响应: [%1]").arg(response.trimmed()));
        }
        break;
    }
}

void SmtpClient::onError(QAbstractSocket::SocketError error)
{
    Q_UNUSED(error)

    qDebug() << "[SMTP 错误]" << m_socket->errorString();

    if (!m_finished) {
        m_finished = true;
        emit sigSmtpFinished(false, m_socket->errorString());
    }
}

void SmtpClient::sendCommand(const QByteArray &cmd)
{
    m_socket->write(cmd);
    m_socket->flush();
}