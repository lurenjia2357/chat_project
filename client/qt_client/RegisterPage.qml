import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: _register_page
    width: 300
    height: 500

    signal sigSwitchLogin()

    Timer {
        id: countdown_timer
        interval: 5000
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 10
        anchors.leftMargin: 30
        anchors.rightMargin: 30


        Item {
            //Layout.fillHeight: true
            Layout.preferredHeight: 50
            implicitHeight: 0
            implicitWidth: 0
        }

        Label {
            id: error_tip
            Layout.fillWidth: true
            Layout.preferredHeight: 25
            text: "测试"
            color: "red"
            font.pixelSize: 14
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }

        Item {
            //Layout.fillHeight: true
            Layout.preferredHeight: 15
            implicitHeight: 0
            implicitWidth: 0
        }

        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            Label {
                id: user_label
                font.pixelSize: 14
                text: "用户："
                Layout.preferredHeight: 25
                Layout.preferredWidth: 50
                verticalAlignment: Text.AlignVCenter
            }

            TextField {
                id: user_edit
                Layout.preferredHeight: 25
                Layout.fillWidth: true
                leftPadding: 5
                verticalAlignment: Text.AlignVCenter
            }
        }

        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            Label {
                id: email_label
                font.pixelSize: 14
                text: "邮箱："
                Layout.preferredHeight: 25
                Layout.preferredWidth: 50
                verticalAlignment: Text.AlignVCenter
            }

            TextField {
                id: email_edit
                Layout.preferredHeight: 25
                Layout.fillWidth: true
                leftPadding: 5
                verticalAlignment: Text.AlignVCenter
            }
        }

        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            Label {
                id: password_label
                font.pixelSize: 14
                text: "密码："
                Layout.preferredHeight: 25
                Layout.preferredWidth: 50
                verticalAlignment: Text.AlignVCenter
            }

            TextField {
                id: password_edit
                echoMode: TextInput.Password
                Layout.preferredHeight: 25
                Layout.fillWidth: true
                leftPadding: 5
                verticalAlignment: Text.AlignVCenter
            }
        }

        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            Label {
                id: confirm_label
                font.pixelSize: 14
                text: "确认："
                Layout.preferredHeight: 25
                Layout.preferredWidth: 50
                verticalAlignment: Text.AlignVCenter
            }

            TextField {
                id: confirm_edit
                echoMode: TextInput.Password
                Layout.preferredHeight: 25
                Layout.fillWidth: true
                leftPadding: 5
                verticalAlignment: Text.AlignVCenter
            }
        }

        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            Label {
                id: verify_label
                font.pixelSize: 14
                text: "验证码："
                Layout.preferredHeight: 25
                Layout.preferredWidth: 50
                verticalAlignment: Text.AlignVCenter
            }

            TextField {
                id: verify_edit
                Layout.preferredHeight: 25
                Layout.fillWidth: true
                leftPadding: 5
                verticalAlignment: Text.AlignVCenter
            }

            RoundButton {
                id: verify_button
                Layout.preferredHeight: 25
                Layout.preferredWidth: 50
                text: "获取"
                radius: 5

                onClicked: {
                    if (email_edit.text === "") {
                        error_tip.text = "请先输入邮箱地址"
                        error_tip.color = "red"

                        return
                    }

                    var emailRegex = /^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$/
                    if (!emailRegex.test(email_edit.text)) {
                        error_tip.text = "邮箱格式不正确"
                        error_tip.color = "red"

                        return
                    }

                    verify_button.enabled = false
                    verify_button.text = "发送中..."

                    var xhr = new XMLHttpRequest()
                    xhr.open("POST", "http://127.0.0.1:10086/send_email")
                    xhr.setRequestHeader("Content-Type", "text/plain")

                    xhr.onreadystatechange = function() {
                        if (xhr.readyState === XMLHttpRequest.DONE) {
                            verify_button.enabled = true
                            verify_button.text = "获取"

                            if (xhr.status === 202) {
                                error_tip.text = "验证码已发送，请查收邮箱"
                                error_tip.color = "green"
                            } else if (xhr.status === 429) {
                                error_tip.text = "发送过于频繁，请30秒后再试"
                                error_tip.color = "red"
                            } else {
                                error_tip.text = "请求失败：" + xhr.responseText
                                error_tip.color = "red"
                            }
                        }
                    }

                    xhr.send(email_edit.text)
                }
            }
        }

        Item {
            Layout.fillHeight: true
            implicitHeight: 0
            implicitWidth: 0
        }

        RowLayout {
            Layout.alignment: Qt.AlignHCenter

            RoundButton {
                id: sure_button
                Layout.preferredHeight: 25
                Layout.fillWidth: true
                text: "确认"
                radius: 5

                onClicked: {
                    if (user_edit.text === "" || email_edit.text === "" ||
                            password_edit.text === "" || confirm_edit.text === "" ||
                            verify_edit.text === "") {
                        error_tip.text = "请填写所有字段"
                        error_tip.color = "red"
                        return
                    }
                    if (password_edit.text !== confirm_edit.text) {
                        error_tip.text = "两次密码不一致"
                        error_tip.color = "red"
                        return
                    }

                    sure_button.enabled = false
                    sure_button.text = "注册中..."

                    var body = "username=" + encodeURIComponent(user_edit.text)
                            + "&email=" + encodeURIComponent(email_edit.text)
                            + "&password=" + encodeURIComponent(password_edit.text)
                            + "&code=" + encodeURIComponent(verify_edit.text)

                    var xhr = new XMLHttpRequest()
                    xhr.open("POST", "http://127.0.0.1:10086/register_user")
                    xhr.setRequestHeader("Content-Type",
                                         "application/x-www-form-urlencoded")

                    xhr.onreadystatechange = function() {
                        if (xhr.readyState !== XMLHttpRequest.DONE) return

                        sure_button.enabled = true
                        sure_button.text = "确认"

                        if (xhr.status === 200) {
                            error_tip.text = "注册成功！五秒后返回登录界面···"
                            error_tip.color = "green"
                            countdown_timer.triggered.connect(function() {
                                _register_page.sigSwitchLogin()
                            })

                            countdown_timer.start()
                        } else if (xhr.status === 409) {
                            error_tip.text = "用户名或邮箱已存在"
                            error_tip.color = "red"
                        } else if (xhr.status === 401) {
                            error_tip.text = "验证码错误或已过期"
                            error_tip.color = "red"
                        } else {
                            error_tip.text = xhr.responseText
                            error_tip.color = "red"
                        }
                    }

                    xhr.send(body)
                }
            }

            RoundButton {
                id: cancel_button
                Layout.preferredHeight: 25
                Layout.fillWidth: true
                text: "取消"
                radius: 5
                onClicked: _register_page.sigSwitchLogin()
            }
        }

        Item {
            Layout.fillHeight: true
            implicitHeight: 0
            implicitWidth: 0
        }
    }
}
