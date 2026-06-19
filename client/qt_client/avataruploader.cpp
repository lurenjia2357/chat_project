#include "avataruploader.h"
#include <QFile>
#include <QFileInfo>
#include <QDir>
#include <QUrl>
#include <QNetworkAccessManager>
#include <QNetworkRequest>
#include <QNetworkReply>
#include <QUrlQuery>
#include <QEventLoop>
#include <QCoreApplication>
#include <QDateTime>

AvatarUploader::AvatarUploader(QObject *parent)
    : QObject{parent}
{}

QString AvatarUploader::copyAndUpload(int userId, const QString &localFilePath)
{
    // 1. file:///D: → D:/
    QString src = localFilePath;
    if (src.startsWith("file:///")) {
        src = QUrl(src).toLocalFile();
    }

    // 2. 取后缀，生成文件名 avatar_1.jpg
    QString suffix = QFileInfo(src).suffix().toLower();
    if (suffix != "jpg" && suffix != "jpeg" && suffix != "png") {
        suffix = "jpg";
    }

    QString destName = QString("avatar_%1.%2").arg(userId).arg(suffix);

    // 3. 复制到 exe 所在目录的 image/ 下
    QString destDir = QCoreApplication::applicationDirPath() + "/image";
    QDir().mkpath(destDir);
    QString destPath = destDir + "/" + destName;

    if (QFile::exists(destPath)) {
        QFile::remove(destPath);
    }

    if (!QFile::copy(src, destPath)) {
        return "";
    }

    // 4. 构造 file:/// 路径
    QString newAvatar = "file:///" + destPath;

    // 5. 发 POST 通知服务端更新数据库
    QNetworkAccessManager mgr;
    QNetworkRequest req(QUrl("http://127.0.0.1:10086/update_avatar"));
    req.setHeader(QNetworkRequest::ContentTypeHeader, "application/x-www-form-urlencoded");

    QUrlQuery query;
    query.addQueryItem("user_id", QString::number(userId));
    query.addQueryItem("avatar", newAvatar);

    QNetworkReply *reply = mgr.post(req, query.toString().toUtf8());

    QEventLoop loop;
    QObject::connect(reply, &QNetworkReply::finished, &loop, &QEventLoop::quit);
    loop.exec();

    if (reply->error() != QNetworkReply::NoError) {
        reply->deleteLater();
        return "";
    }

    reply->deleteLater();
    return newAvatar + "?t=" + QString::number(QDateTime::currentSecsSinceEpoch());
}
