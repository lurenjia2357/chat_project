    // Set up code that uses the Qt event loop here.
// Call QCoreApplication::quit() or QCoreApplication::exit() to quit the application.
// A not very useful example would be including
// #include <QTimer>
// near the top of the file and calling
// QTimer::singleShot(5000, &a, &QCoreApplication::quit);
// which quits the application after 5 seconds.

// If you do not need a running Qt event loop, remove the call
// to QCoreApplication::exec() or use the Non-Qt Plain C++ Application template.

#include <QCoreApplication>
#include <QLocale>
#include <QTranslator>
#include "verifyserver.h"
#include "registeruser.h"

int main(int argc, char *argv[])
{
    QCoreApplication a(argc, argv);

    if (!RegisterUser::instance().connect("10.0.0.100", 3308, "db_new_chat", "root", "123456"))
    {
        return -1;
    }

    QTranslator translator;
    const QStringList uiLanguages = QLocale::system().uiLanguages();
    for (const QString &locale : uiLanguages) {
        const QString baseName = "qt_verify_server_" + QLocale(locale).name();
        if (translator.load(":/i18n/" + baseName)) {
            a.installTranslator(&translator);
            break;
        }
    }

    VerifyServer server;

    if (!server.start()) {
        return -1;
    }

    return QCoreApplication::exec();
}
