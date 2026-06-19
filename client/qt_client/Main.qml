import QtQuick
import QtQuick.Controls

Window {
    id: rootWindow
    width: 300
    height: 500
    visible: true
    title: qsTr("Chat")

    property bool sizeLocked: stack_view.visible
    property int loginUserId: 0
    property string loginUserName: ""
    property string loginAvatar: ""
    property string loginEmail: ""

    minimumWidth: sizeLocked ? 300 : 0
    maximumWidth: sizeLocked ? 300 : 99999
    minimumHeight: sizeLocked ? 500 : 0
    maximumHeight: sizeLocked ? 500 : 99999

    Component {
        id: _register_page_component

        RegisterPage {
            onSigSwitchLogin: {
                stack_view.pop()
            }
        }
    }

    Component {
        id: _reset_page_component

        ResetPage {
            onSigSwitchLogin: {
                stack_view.pop()
            }
        }
    }

    Timer {
        id: chat_delay_timer
        interval: 1000
        repeat: false

        onTriggered: {
            rootWindow.width = 1100
            rootWindow.height = 800
            chat_page.visible = true
            rootWindow.x = (rootWindow.screen.width - 1100) / 2
            rootWindow.y = (rootWindow.screen.height - 800) / 2
            rootWindow.visible = true
        }
    }

    StackView {
        id: stack_view
        anchors.fill: parent

        initialItem: LoginPage {
            onSigSwitchRegister: {
                stack_view.push(_register_page_component)
            }

            onSigSwitchReset: {
                stack_view.push(_reset_page_component)
            }

            onSigSwitchChat: {
                stack_view.visible = false
                rootWindow.visible = false
                chat_delay_timer.start()
            }
        }
    }

    ChatPage {
        id: chat_page
        anchors.fill: parent
        visible: false
        currentUserId: rootWindow.loginUserId
        currentUsername: rootWindow.loginUserName
        currentUserAvatar: rootWindow.loginAvatar
        currentUserEmail: rootWindow.loginEmail
    }

}