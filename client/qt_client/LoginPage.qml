import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: _login_page
    width: 300
    height: 500

    signal sigSwitchRegister()
    signal sigSwitchReset()
    signal sigSwitchChat()

    ColumnLayout {
        anchors.fill: parent
        spacing: 10

        Item {
            Layout.fillHeight: true
            Layout.preferredHeight: 10
            implicitHeight: 0
            implicitWidth: 0
        }

        Label {
            id: error_tip
            Layout.fillWidth: true
            Layout.preferredHeight: 25
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            text: "错误提示"
            color: "red"
            font.pixelSize: 14
        }

        Item {
            Layout.fillHeight: true
            implicitHeight: 0
            implicitWidth: 0
        }

        Image {
            id: login_head
            source: "qrc:/image/user_avatar.png"
            Layout.preferredHeight: 125
            Layout.preferredWidth: 125
            Layout.alignment: Qt.AlignHCenter
            fillMode: Image.PreserveAspectFit
        }

        Item {
            Layout.preferredHeight: 20
            Layout.fillHeight: true
            implicitHeight: 0
            implicitWidth: 0
        }

        ColumnLayout {
            Layout.fillHeight: true
            Layout.fillWidth: true
            Layout.leftMargin: 15
            Layout.rightMargin: 15

            RowLayout {
                Label {
                    id: user_label
                    text: "用户名："
                    Layout.preferredHeight: 25
                    Layout.preferredWidth: 50
                    verticalAlignment: Text.AlignVCenter
                    font.pixelSize: 14

                }

                TextField {
                    id: user_edit
                    Layout.fillWidth: true
                    Layout.preferredHeight: 25
                    placeholderText: "请输入用户名···"
                    leftPadding: 5
                    font.pixelSize: 14
                    topPadding: 0
                    bottomPadding: 0
                    verticalAlignment: Text.AlignVCenter
                }
            }

            RowLayout {
                Label {
                    id: password_label
                    text: "密码："
                    Layout.preferredHeight: 25
                    Layout.preferredWidth: 50
                    verticalAlignment: Text.AlignVCenter
                    font.pixelSize: 14

                }

                TextField {
                    id: password_edit
                    Layout.fillWidth: true
                    Layout.preferredHeight: 25
                    placeholderText: "请输入密码···"
                    leftPadding: 5
                    font.pixelSize: 14
                    topPadding: 0
                    bottomPadding: 0
                    verticalAlignment: Text.AlignVCenter
                }
            }

            RowLayout {
                Item {
                    Layout.fillWidth: true
                    implicitHeight: 0
                    implicitWidth: 0
                }

                Label {
                    id: forget_password
                    Layout.preferredHeight: 25
                    text: "忘记密码?"
                    font.pixelSize: 14
                    color: hover_handler.hovered ? "#4A90D9" : "black"

                    TapHandler {
                        onTapped: _login_page.sigSwitchReset()
                    }

                    HoverHandler {
                        id: hover_handler
                        cursorShape: Qt.PointingHandCursor
                    }
                }
            }

            Item {
                Layout.fillHeight: true
                implicitHeight: 0
                implicitWidth: 0
            }

            RowLayout {
                Item {
                    Layout.fillWidth: true
                    implicitHeight: 0
                    implicitWidth: 0
                }

                RoundButton {
                    id: login_button
                    text: "登录"
                    radius: 5
                    Layout.preferredHeight: 35
                    Layout.preferredWidth: 110
                    font.pixelSize: 14

                    onClicked: {
                        if (user_edit.text.trim() === "" || password_edit.text.trim() === "") {
                            error_tip.text = "用户名和密码不能为空"
                            error_tip.color = "red"
                            return
                        }

                        login_button.enabled = false
                        login_button.text = "登录中..."

                        var xhr = new XMLHttpRequest()
                        xhr.open("POST", "http://127.0.0.1:10086/login")
                        xhr.setRequestHeader("Content-Type",
                                             "application/x-www-form-urlencoded")

                        xhr.onreadystatechange = function() {
                            if (xhr.readyState !== XMLHttpRequest.DONE) return

                            login_button.enabled = true
                            login_button.text = "登录"

                            if (xhr.status === 200) {
                                var resp = JSON.parse(xhr.responseText)
                                rootWindow.loginUserId = resp.user_id
                                rootWindow.loginUserName = resp.username
                                rootWindow.loginAvatar = resp.avatar
                                rootWindow.loginEmail = resp.email
                                _login_page.sigSwitchChat()
                            } else if (xhr.status === 401) {
                                error_tip.text = "用户名或密码错误"
                                error_tip.color = "red"
                            } else {
                                error_tip.text = "登录失败: " + xhr.responseText
                                error_tip.color = "red"
                            }
                        }

                        var body = "username=" + encodeURIComponent(user_edit.text)
                                + "&password=" + encodeURIComponent(password_edit.text)
                        xhr.send(body)
                    }
                }

                Item {
                    Layout.fillWidth: true
                    implicitHeight: 0
                    implicitWidth: 0
                }
            }

            RowLayout {
                Item {
                    Layout.fillWidth: true
                    implicitHeight: 0
                    implicitWidth: 0
                }

                RoundButton {
                    id: register_button
                    text: "注册"
                    radius: 5
                    Layout.preferredHeight: 35
                    Layout.preferredWidth: 110
                    font.pixelSize: 14
                    onClicked: _login_page.sigSwitchRegister()
                }

                Item {
                    Layout.fillWidth: true
                    implicitHeight: 0
                    implicitWidth: 0
                }
            }

            Item {
                Layout.fillHeight: true
                implicitHeight: 0
                implicitWidth: 0
            }
        }
    }
}
