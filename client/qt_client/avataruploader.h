#ifndef AVATARUPLOADER_H
#define AVATARUPLOADER_H

#include <QObject>

class AvatarUploader : public QObject
{
    Q_OBJECT
public:
    explicit AvatarUploader(QObject *parent = nullptr);
    Q_INVOKABLE QString copyAndUpload(int userId, const QString &localFilePath);

signals:
};

#endif // AVATARUPLOADER_H
