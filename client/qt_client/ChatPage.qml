import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs

Item {
    id: _chat_page
    width: 1100
    height: 800

    property int currentUserId: 0
    property string currentUsername: ""
    property string currentUserAvatar: ""
    property string currentUserEmail: ""
    property int selectedFriendId: 0
    property var allFriends: []
    property bool isSearchingNonFriend: false
    property int addFriendTargetId: 0
    property bool hasPendingRequest: false
    property string currentFriendAvatar: ""
    property int maxMessageId: 0
    property bool sending: false
    property bool hasUnreadMessages: false
    property var allConversations: []

    RowLayout {
        anchors.fill: parent
        spacing: 0

        ColumnLayout {
            Layout.preferredWidth: 60
            Layout.fillHeight: true

            Rectangle {
                Layout.fillHeight: true
                Layout.fillWidth: true
                color: "#232323"

                Image {
                    id: self_avatar
                    source: (_chat_page.currentUserAvatar !== ""
                             && _chat_page.currentUserAvatar !== "default_avatar")
                            ? _chat_page.currentUserAvatar
                            : "qrc:/image/avatar_1.jpg"

                    width: 35
                    height: 35
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top
                    anchors.topMargin: 20

                    TapHandler {
                        onTapped: avatar_popup.visible = !avatar_popup.visible
                    }

                    HoverHandler {
                        cursorShape: Qt.PointingHandCursor
                    }
                }

                Image {
                    id: chat_icon
                    width: 35
                    height: 35
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: self_avatar.bottom
                    anchors.topMargin: 40

                    property bool selected: true

                    source: selected ? "qrc:/image/chat_icon_press.png"
                                     : (chat_hover_handler.hovered ? "qrc:/image/chat_icon_hover.png"
                                                                   : "qrc:/image/chat_icon.png")

                    HoverHandler {
                        id: chat_hover_handler
                        cursorShape: Qt.PointingHandCursor
                    }

                    TapHandler {
                        onTapped: {
                            chat_icon.selected = true
                            contact_icon.selected = false
                            search_edit.text = ""
                            loadConversations()
                        }
                    }

                    Image {
                        source: "qrc:/image/red_point.png"
                        width: 25
                        height: 25
                        anchors.right: parent.right
                        anchors.top: parent.top
                        visible: _chat_page.hasUnreadMessages
                        z: 10
                    }
                }

                Image {
                    id: contact_icon
                    width: 35
                    height: 35
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: chat_icon.bottom
                    anchors.topMargin: 40

                    property bool selected: false

                    source: selected ? "qrc:/image/contact_list_press.png"
                                     : (contact_hover_handler.hovered ? "qrc:/image/contact_list_hover.png"
                                                                      : "qrc:/image/contact_list.png")

                    HoverHandler {
                        id: contact_hover_handler
                        cursorShape: Qt.PointingHandCursor
                    }

                    TapHandler {
                        onTapped: {
                            chat_icon.selected = false
                            contact_icon.selected = true
                            search_edit.text = ""
                        }
                    }
                }
            }
        }

        ColumnLayout {
            id: friend_list_column
            Layout.preferredWidth: 240
            Layout.fillHeight: true
            spacing: 0

            Rectangle {
                id: friend_list
                Layout.fillHeight: true
                Layout.fillWidth: true
                color: "#EEEEEE"

                RowLayout {
                    id: search_bar
                    width: parent.width
                    height: 75
                    spacing: 0

                    TextField {
                        id: search_edit
                        Layout.alignment: Qt.AlignVCenter
                        Layout.leftMargin: 10
                        Layout.preferredHeight: 25
                        Layout.preferredWidth: parent.width - 45
                        placeholderText: "搜索"
                        leftPadding: 30
                        font.pixelSize: 14
                        verticalAlignment: Text.AlignVCenter

                        Image {
                            id: search_icon
                            anchors.left: parent.left
                            anchors.leftMargin: 5
                            source: "qrc:/image/search.png"
                            width: 18
                            height: 18
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Image {
                            id: clear_icon
                            anchors.right: parent.right
                            anchors.rightMargin: 5
                            anchors.verticalCenter: parent.verticalCenter
                            source: "qrc:/image/close_search.png"
                            width: 18
                            height: 18
                            visible: search_edit.text !== ""

                            TapHandler {
                                onTapped: {
                                    search_edit.text = "";
                                    search_edit.forceActiveFocus();
                                }
                            }

                            HoverHandler {
                                cursorShape: Qt.PointingHandCursor
                            }
                        }
                    }

                    Item {
                        Layout.alignment: Qt.AlignVCenter
                        Layout.preferredHeight: 25
                        Layout.preferredWidth: 25
                        Layout.rightMargin: 5

                        // 底层：原图标
                        Image {
                            id: add_friend_request
                            anchors.fill: parent
                            source: add_friend_req_tap.pressed
                                    ? "qrc:/image/add_friend_press.png"
                                    : (add_friend_req_hover.hovered
                                       ? "qrc:/image/add_friend_hover.png"
                                       : "qrc:/image/add_friend_normal.png")

                            HoverHandler {
                                id: add_friend_req_hover
                                cursorShape: Qt.PointingHandCursor
                            }

                            TapHandler {
                                id: add_friend_req_tap
                                onTapped: {
                                    _chat_page.hasPendingRequest = false
                                    placeholder_image.visible = false
                                    chat_content.visible = false
                                    pending_requests_view.visible = true

                                    var reqXhr = new XMLHttpRequest()
                                    reqXhr.open("GET", "http://127.0.0.1:10086/pending_requests?user_id=" + _chat_page.currentUserId)
                                    reqXhr.onreadystatechange = function() {
                                        if (reqXhr.readyState !== XMLHttpRequest.DONE) return
                                        pending_request_model.clear()

                                        // 情况1：服务器未启动
                                        if (reqXhr.status === 0) {
                                            pending_empty_label.text = "服务器连接失败"
                                            pending_empty_label.visible = true
                                            return
                                        }

                                        // 情况2：服务器返回错误
                                        if (reqXhr.status !== 200) {
                                            pending_empty_label.text = "加载失败 (错误码: " + reqXhr.status + ")"
                                            pending_empty_label.visible = true
                                            return
                                        }

                                        // 情况3：正常响应
                                        var requests
                                        try {
                                            requests = JSON.parse(reqXhr.responseText)
                                        } catch (e) {
                                            pending_empty_label.text = "数据解析失败"
                                            pending_empty_label.visible = true
                                            return
                                        }

                                        // 情况4：无待处理请求
                                        if (requests.length === 0) {
                                            pending_empty_label.text = "没有待处理的好友请求"
                                            pending_empty_label.visible = true
                                            return
                                        }

                                        // 正常：渲染列表
                                        pending_empty_label.visible = false
                                        for (var i = 0; i < requests.length; i++) {
                                            var r = requests[i]
                                            pending_request_model.append({
                                                userId: r.user_id,
                                                username: r.username,
                                                avatar: r.avatar || "default_avatar"
                                            })
                                        }
                                    }
                                    reqXhr.send()
                                }
                            }
                        }

                        // 上层：红点
                        Image {
                            source: "qrc:/image/red_point.png"
                            width: 25
                            height: 25
                            anchors.right: parent.right
                            anchors.top: parent.top
                            visible: _chat_page.hasPendingRequest
                            z: 10
                        }
                    }
                }

                Item {
                    id: add_friend_shim
                    anchors.top: search_bar.bottom
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: search_edit.text.trim() !== "" ? 55 : 0

                    Rectangle {
                        id: add_friend_entry
                        anchors.fill: parent
                        visible: add_friend_shim.height > 0 && contact_icon.selected
                        color: add_friend_hover.hovered ? "#DADADA" : "transparent"

                        Image {
                            source: "qrc:/image/add_friend_normal.png"
                            width: 42; height: 42
                            anchors.left: parent.left
                            anchors.leftMargin: 12
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Label {
                            text: "添加新朋友"
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.verticalCenter: parent.verticalCenter
                            font.pixelSize: 16
                            color: "#222222"
                        }

                        Rectangle {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            height: 1
                            color: "#E0E0E0"
                        }

                        HoverHandler {
                            id: add_friend_hover
                            cursorShape: Qt.PointingHandCursor
                        }

                        TapHandler {
                            onTapped: {
                                _chat_page.isSearchingNonFriend = true
                                var keyword = search_edit.text.trim()
                                var xhr = new XMLHttpRequest()
                                xhr.open("GET", "http://127.0.0.1:10086/search_user?keyword="
                                         + encodeURIComponent(keyword)
                                         + "&user_id=" + _chat_page.currentUserId)
                                xhr.onreadystatechange = function() {
                                    if (xhr.readyState !== XMLHttpRequest.DONE) return
                                    friend_model.clear()
                                    no_result_label.visible = false

                                    // 情况1：网络不通或服务器未启动
                                    if (xhr.status === 0) {
                                        no_result_label.text = "服务器连接失败"
                                        no_result_label.visible = contact_icon.selected
                                        return
                                    }

                                    // 情况2：服务器返回错误
                                    if (xhr.status !== 200) {
                                        no_result_label.text = "搜索失败 (错误码: " + xhr.status + ")"
                                        no_result_label.visible = contact_icon.selected
                                        return
                                    }

                                    // 情况3：正常响应
                                    var users
                                    try {
                                        users = JSON.parse(xhr.responseText)
                                    } catch (e) {
                                        no_result_label.text = "数据解析失败"
                                        no_result_label.visible = contact_icon.selected
                                        return
                                    }

                                    // 情况4：无匹配
                                    if (users.length === 0) {
                                        no_result_label.text = "未找到相关用户"
                                        no_result_label.visible = contact_icon.selected
                                        return
                                    }

                                    // 正常：渲染结果
                                    for (var i = 0; i < users.length; i++) {
                                        var u = users[i]
                                        friend_model.append({
                                            userId: u.user_id,
                                            username: u.username,
                                            avatar: u.avatar || "default_avatar"
                                        })
                                    }
                                }

                                xhr.send()
                            }
                        }
                    }
                }

                Label {
                    id: no_result_label
                    anchors.top: add_friend_shim.bottom
                    anchors.topMargin: 15
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "未找到匹配的好友"
                    font.pixelSize: 16
                    color: "#888888"
                    visible: contact_icon.selected && friend_model.count === 0 && !add_friend_shim.height
                }

                ListView {
                    id: friend_list_view
                    anchors.top: add_friend_shim.bottom
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    anchors.right: parent.right
                    clip: true
                    spacing: 0
                    visible: contact_icon.selected

                    model: ListModel {
                        id: friend_model
                    }

                    delegate: Rectangle {
                        id: friend_item
                        width: friend_list_view.width
                        height: 55
                        color: chat_page.selectedFriendId === model.userId
                               ? "#D0D0D0"
                               : (friend_item_mouse.containsMouse ? "#DEDEDE" : "transparent")

                        // 左侧蓝条（选中标记）
                        Rectangle {
                            visible: _chat_page.selectedFriendId === model.userId
                            anchors.left: parent.left
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            width: 3
                            color: "#4A90D9"
                        }

                        // 头像（左对齐）
                        Image {
                            id: friend_avatar
                            source: model.avatar !== "default_avatar"
                                       ? model.avatar
                                       : "qrc:/image/avatar_1.jpg"
                            width: 40
                            height: 40
                            anchors.left: parent.left
                            anchors.leftMargin: 12
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        // 名字（在头像右边，间距10px）
                        Label {
                            text: model.username
                            anchors.left: friend_avatar.right
                            anchors.leftMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            font.pixelSize: 15
                            color: "#222222"
                        }

                        // 底部分割线
                        Rectangle {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            height: 1
                            color: "#E0E0E0"
                        }

                        MouseArea {
                            id: friend_item_mouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            acceptedButtons: Qt.NoButton
                        }

                        TapHandler {
                            onTapped: {
                                // 搜索结果中的非好友 -> 弹出添加弹窗
                                if (_chat_page.isSearchingNonFriend && model.userId > 0) {
                                    add_friend_popup.visible = true
                                    addFriendTargetId = model.userId
                                    add_friend_target_name.text = model.username
                                    return
                                }

                                // 正常好友 -> 打开聊天
                                pending_requests_view.visible = false
                                _chat_page.selectedFriendId = model.userId
                                chat_partner.text = model.username
                                _chat_page.currentFriendAvatar = model.avatar
                                chat_content.visible = true
                                placeholder_image.visible = false
                                friend_list_view.forceLayout()
                                loadMessages(model.userId)
                            }
                        }
                    }
                }

                ListView {
                    id: conversation_list_view
                    anchors.top: search_bar.bottom
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    anchors.right: parent.right
                    clip: true
                    spacing: 0
                    visible: chat_icon.selected

                    model: ListModel {
                        id: conversation_model
                    }

                    delegate: Rectangle {
                        id: conversation_item
                        width: conversation_list_view.width
                        height: 55
                        color: _chat_page.selectedFriendId === model.friendId
                               ? "#D0D0D0"
                               : (conv_item_mouse.containsMouse ? "#DEDEDE" : "transparent")

                        Rectangle {
                            visible: _chat_page.selectedFriendId === model.friendId
                            anchors.left: parent.left
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            width: 3
                            color: "#4A90D9"
                        }

                        Image {
                            id: conv_avatar
                            source: model.avatar !== "" && model.avatar !== "default_avatar"
                                    ? model.avatar
                                    : "qrc:/image/avatar_1.jpg"
                            width: 40
                            height: 40
                            anchors.left: parent.left
                            anchors.leftMargin: 12
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Label {
                            text: model.friendName
                            anchors.left: conv_avatar.right
                            anchors.leftMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            font.pixelSize: 15
                            color: "#222222"
                        }

                        // 时间（右上角）
                        Label {
                            text: model.lastTime
                            anchors.right: parent.right
                            anchors.rightMargin: 12
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 10
                            font.pixelSize: 10
                            color: "#999999"
                        }

                        // 红点
                        Image {
                            source: "qrc:/image/red_point.png"
                            width: 25
                            height: 25
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.rightMargin: 0
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 2
                            visible: model.unreadCount > 0
                            z: 10
                        }

                        Rectangle {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            height: 1
                            color: "#E0E0E0"
                        }

                        MouseArea {
                            id: conv_item_mouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            acceptedButtons: Qt.NoButton
                        }

                        TapHandler {
                            onTapped: {
                                pending_requests_view.visible = false
                                _chat_page.selectedFriendId = model.friendId
                                chat_partner.text = model.friendName
                                _chat_page.currentFriendAvatar = model.avatar
                                chat_content.visible = true
                                placeholder_image.visible = false

                                // 标记已读
                                markConversationRead(model.friendId)
                                model.unreadCount = 0
                                updateConversationBadge()
                                loadMessages(model.friendId)
                            }
                        }
                    }
                }

                // 对话列表为空时的提示
                Label {
                    id: conversation_empty_label
                    anchors.top: search_bar.bottom
                    anchors.topMargin: 30
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "暂无对话"
                    font.pixelSize: 16
                    color: "#888888"
                    visible: chat_icon.selected && conversation_model.count === 0
                }
            }
        }

        ColumnLayout {
            spacing: 0
            Layout.preferredWidth: 800
            Layout.fillHeight: true

            Rectangle {
                Layout.fillHeight: true
                Layout.fillWidth: true
                color: "#E5E5E5"

                Image {
                    id: placeholder_image
                    source: "qrc:/image/chat_background_icon.png"
                    anchors.centerIn: parent
                    visible: !chat_content.visible
                }

                ColumnLayout {
                    id: chat_content
                    visible: false
                    spacing: 0
                    anchors.fill: parent

                    Label {
                        id: chat_partner
                        Layout.alignment: Qt.AlignTop
                        Layout.fillWidth: true
                        Layout.preferredHeight: 60
                        leftPadding: 15
                        text: "陆仁贾"
                        verticalAlignment: Text.AlignVCenter
                        font.pixelSize: 20
                    }

                    ListView {
                        id: dialogue_content
                        Layout.fillHeight: true
                        Layout.fillWidth: true
                        clip: true
                        spacing: 10
                        topMargin: 10
                        bottomMargin: 10

                        ScrollBar.vertical: ScrollBar {
                            policy: ScrollBar.AsNeeded
                            visible: dialogue_content.contentHeight > dialogue_content.height

                            contentItem: Rectangle {
                                implicitWidth: 3
                                radius: 2
                                color: "#C0C0C0"
                            }
                        }

                        model: ListModel {
                            id: message_model
                        }

                        delegate: Item {
                            width: dialogue_content.width
                            height: dialogue_bubble.height + 6

                            // 头像
                            Image {
                                id: dialogue_avatar
                                anchors.left: model.isMine ? undefined : parent.left
                                anchors.right: model.isMine ? parent.right : undefined
                                anchors.leftMargin: model.isMine ? 0 : 8
                                anchors.rightMargin: model.isMine ? 8 : 0
                                anchors.top: dialogue_bubble.top

                                source: model.isMine
                                        ? self_avatar.source
                                        : (_chat_page.currentFriendAvatar !== "" &&
                                           _chat_page.currentFriendAvatar !== "default_avatar"
                                           ? _chat_page.currentFriendAvatar
                                           : "qrc:/image/avatar_1.jpg")
                                width: 35
                                height: 35
                            }

                            // 气泡
                            Rectangle {
                                id: dialogue_bubble
                                y: 3
                                anchors.right: model.isMine ? dialogue_avatar.left : undefined
                                anchors.left: model.isMine ? undefined : dialogue_avatar.right
                                anchors.rightMargin: model.isMine ? 8 : 0
                                anchors.leftMargin: model.isMine ? 0 : 8

                                width: Math.min(msg_label.implicitWidth + 24, dialogue_content.width * 0.4)
                                height: msg_label.implicitHeight + 16
                                radius: 6
                                color: model.isMine ? "#95EC69" : "white"

                                TextEdit {
                                    id: msg_label
                                    anchors.centerIn: parent
                                    text: model.text
                                    font.pixelSize: 15
                                    wrapMode: TextEdit.Wrap
                                    width: parent.width - 24
                                    readOnly: true
                                    selectByMouse: true
                                    color: "black"
                                }
                            }
                        }

                        onCountChanged: {
                            if (message_model.count > 0) {
                                positionViewAtEnd()
                            }
                        }
                    }

                    ScrollView {
                        id: message_scroll
                        Layout.preferredHeight: 165
                        Layout.fillWidth: true
                        Layout.bottomMargin: 0

                        TextArea {
                            id: message_edit
                            verticalAlignment: TextEdit.AlignTop
                            font.pixelSize: 18
                            wrapMode: TextArea.Wrap

                            background: Rectangle {
                               color: "white"
                            }
                        }
                    }

                    Rectangle {
                        id: send_bar
                        Layout.topMargin: 0
                        Layout.preferredHeight: 35
                        Layout.fillWidth: true
                        color: "white"

                        RoundButton {
                            id: send_button
                            anchors.right: parent.right
                            anchors.rightMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            text: "发送"
                            width: 100
                            height: 25
                            radius: 5

                            onClicked: {
                                var msg = message_edit.text.trim()
                                if (msg === "") return
                                if (_chat_page.selectedFriendId <= 0) return

                                // 1. 立刻显示气泡
                                var tempId = -Date.now()
                                message_model.append({
                                    messageId: tempId,
                                    text: msg,
                                    isMine: true
                                })

                                // 2. 滚动到底部
                                dialogue_content.positionViewAtEnd()

                                // 3. 清空输入框
                                message_edit.text = ""

                                // 4. 锁定轮询
                                _chat_page.sending = true

                                // 5. 发送到服务端
                                var xhr = new XMLHttpRequest()
                                xhr.open("POST", "http://127.0.0.1:10086/send_message")
                                xhr.setRequestHeader("Content-Type",
                                                     "application/x-www-form-urlencoded")
                                xhr.onreadystatechange = function() {
                                    if (xhr.readyState !== XMLHttpRequest.DONE) return
                                    if (xhr.status === 200) {
                                        var resp = JSON.parse(xhr.responseText)

                                        // 把临时 ID 替换为服务端真实 ID
                                        for (var i = 0; i < message_model.count; i++) {
                                            if (message_model.get(i).messageId === tempId) {
                                                message_model.setProperty(i, "messageId", resp.id)
                                                break
                                            }
                                        }

                                        if (resp.id > _chat_page.maxMessageId) {
                                            _chat_page.maxMessageId = resp.id
                                        }

                                        updateLocalConversation(
                                             _chat_page.selectedFriendId,
                                            chat_partner.text,
                                            _chat_page.currentFriendAvatar
                                        )
                                    }

                                    _chat_page.sending = false
                                }
                                xhr.send("from_user_id=" + _chat_page.currentUserId
                                         + "&to_user_id=" + _chat_page.selectedFriendId
                                         + "&content=" + encodeURIComponent(msg))
                            }
                        }
                    }
                }

                // ========== 待处理好友请求页面 ==========
                ColumnLayout {
                    id: pending_requests_view
                    visible: false
                    spacing: 0
                    anchors.fill: parent

                    Label {
                        id: pending_empty_label
                        text: "没有待处理的好友请求"
                        font.pixelSize: 20
                        color: "#888888"
                        Layout.alignment: Qt.AlignHCenter
                        Layout.topMargin: 30
                        visible: false
                    }

                    ListView {
                        id: pending_request_list
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        visible: !pending_empty_label.visible

                        model: ListModel {
                            id: pending_request_model
                        }

                        delegate: Rectangle {
                            width: pending_request_list.width
                            height: 70
                            color: "transparent"

                            // 头像
                            Image {
                                id: pending_avatar
                                source: model.avatar !== "default_avatar" && model.avatar !== ""
                                        ? model.avatar
                                        : "qrc:/image/avatar_1.jpg"
                                width: 45
                                height: 45
                                anchors.left: parent.left
                                anchors.leftMargin: 20
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            // 名字
                            Label {
                                text: model.username
                                anchors.left: pending_avatar.right
                                anchors.leftMargin: 12
                                anchors.verticalCenter: parent.verticalCenter
                                font.pixelSize: 16
                                color: "#222222"
                            }

                            // 拒绝按钮
                            RoundButton {
                                text: "拒绝"
                                width: 60
                                height: 28
                                radius: 4
                                anchors.right: parent.right
                                anchors.rightMargin: 20
                                anchors.verticalCenter: parent.verticalCenter
                                onClicked: {
                                    _chat_page.hasPendingRequest = false

                                    var rejXhr = new XMLHttpRequest()
                                    rejXhr.open("POST", "http://127.0.0.1:10086/reject_friend")
                                    rejXhr.setRequestHeader("Content-Type", "application/x-www-form-urlencoded")
                                    rejXhr.onreadystatechange = function() {
                                        if (rejXhr.readyState === XMLHttpRequest.DONE && rejXhr.status === 200) {
                                            pending_request_model.remove(model.index, 1)
                                            if (pending_request_model.count === 0) {
                                                pending_empty_label.text = "没有待处理的好友请求"
                                                pending_empty_label.visible = true
                                            }
                                        }
                                    }

                                    rejXhr.send("from_user_id=" + encodeURIComponent(model.userId)
                                                + "&to_user_id=" + encodeURIComponent(_chat_page.currentUserId))
                                }
                            }

                            // 接受按钮
                            RoundButton {
                                text: "接受"
                                width: 60
                                height: 28
                                radius: 4
                                anchors.right: parent.right
                                anchors.rightMargin: 90
                                anchors.verticalCenter: parent.verticalCenter
                                onClicked: {
                                    _chat_page.hasPendingRequest = false

                                    var accXhr = new XMLHttpRequest()
                                    accXhr.open("POST", "http://127.0.0.1:10086/accept_friend")
                                    accXhr.setRequestHeader("Content-Type", "application/x-www-form-urlencoded")
                                    accXhr.onreadystatechange = function() {
                                        if (accXhr.readyState === XMLHttpRequest.DONE && accXhr.status === 200) {
                                            pending_request_model.remove(model.index, 1)
                                            if (pending_request_model.count === 0) {
                                                pending_empty_label.text = "没有待处理的好友请求"
                                                pending_empty_label.visible = true
                                            }

                                            loadFriendList()
                                        }
                                    }
                                    accXhr.send("from_user_id=" + encodeURIComponent(model.userId)
                                                + "&to_user_id=" + encodeURIComponent(_chat_page.currentUserId))
                                }
                            }

                            // 底部分割线
                            Rectangle {
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.bottom: parent.bottom
                                height: 1
                                color: "#E0E0E0"
                            }
                        }
                    }
                }
            }
        }
    }

    // 全屏透明遮罩：点击弹窗以外任意位置关闭弹窗
    MouseArea {
        anchors.fill: parent
        visible: avatar_popup.visible
        onClicked: avatar_popup.visible = false
    }

    // 阴影层（位于弹出层后方，提供底部淡阴影）
    Rectangle {
        id: avatar_popup_shadow
        // 四周各扩展 6px
        y: avatar_popup.y - 6
        height: avatar_popup.height + 12
        // 圆角也要相应加大，保持拐角处阴影自然
        radius: avatar_popup.radius + 6
        // 颜色：极淡的黑色，产生均匀的四周阴影感
        color: "#01200000"
        visible: avatar_popup.visible
        z: avatar_popup.z - 1
    }

    Rectangle {
        id: avatar_popup
        width: 225
        height: 225
        radius: 10
        color: "white"
        visible: false
        z: 10

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
        }

        ColumnLayout {
            id: avatar_column
            anchors.left: parent.left
            anchors.leftMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            spacing: 15

            Image {
                id: avatar
                source: self_avatar.source
                Layout.preferredHeight: 60
                Layout.preferredWidth: 60
            }

            Label {
                id: change_avatar
                text: "更改头像"
                Layout.alignment: Qt.AlignHCenter
                font.pixelSize: 12
                color: change_avatar_hover.hovered ? "#4A90D9" : "#888888"

                HoverHandler {
                    id: change_avatar_hover
                    cursorShape: Qt.PointingHandCursor
                }

                TapHandler {
                    onTapped: avatar_file_dialog.open()
                }
            }
        }

        ColumnLayout {
            anchors.left: avatar_column.right
            anchors.leftMargin: 15
            anchors.top: parent.top
            anchors.bottom: parent.bottom

            Label {
                id: user_name
                text: "用户名：" + "\n" + currentUsername + "\n" + "\n" + "\n" + "邮箱：" + "\n" + currentUserEmail
                font.pixelSize: 12
                Layout.alignment: Qt.AlignHCenter
            }
        }

        onVisibleChanged: {
            if (visible) {
                // 弹窗自身位置
                var headPos = self_avatar.mapToItem(_chat_page, 0, 0)
                var headRight = self_avatar.mapToItem(_chat_page, self_avatar.width, 0)
                avatar_popup.y = headPos.y
                avatar_popup.x = headRight.x + 20

                // 阴影：左右贴住第二个 ColumnLayout
                var col2Pos = friend_list_column.mapToItem(_chat_page, 0, 0)
                avatar_popup_shadow.x = col2Pos.x
                avatar_popup_shadow.width = friend_list_column.width
            }
        }
    }

    Component.onCompleted: {
        if (_chat_page.currentUserId > 0) {
            loadFriendList()
            loadConversations()
        }
    }

    onCurrentUserIdChanged: {//<--为什么要取这个名字？
        if (_chat_page.currentUserId > 0) {
            loadFriendList()
            loadConversations()
        }
    }

    function loadFriendList() {
        var xhr = new XMLHttpRequest()
        xhr.open("GET", "http://127.0.0.1:10086/friend_list?user_id=" + _chat_page.currentUserId)
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE) return

            friend_model.clear()

            // 情况1：网络不通或服务器未启动
            if (xhr.status === 0) {
                friend_model.append({
                    userId: -1,
                    username: "服务器连接失败",
                    avatar: ""
                })

                return
            }

            // 情况2：服务器返回错误
            if (xhr.status !== 200) {
                friend_model.append({
                    userId: -1,
                    username: "加载失败 (错误码: " + xhr.status + ")",
                    avatar: ""
                })

                return
            }

            // 情况3：JSON 解析失败
            var friends
            try {
                friends = JSON.parse(xhr.responseText)
            } catch (e) {
                friend_model.append({
                    userId: -1,
                    username: "数据解析失败",
                    avatar: ""
                })

                return
            }

            allFriends = friends

            // 登录后立即查看是否有待处理的好友请求
            var pendingXhr = new XMLHttpRequest()
            pendingXhr.open("GET", "http://127.0.0.1:10086/pending_count?user_id=" + _chat_page.currentUserId)
            pendingXhr.onreadystatechange = function() {
                if (pendingXhr.readyState === XMLHttpRequest.DONE && pendingXhr.status === 200) {
                    var resp = JSON.parse(pendingXhr.responseText)
                    _chat_page.hasPendingRequest = (resp.count > 0)
                }
            }
            pendingXhr.send()

            // 正常：渲染好友列表
            for (var i = 0; i < friends.length; i++) {
                var f = friends[i]
                friend_model.append({
                    userId: f.user_id,
                    username: f.username,
                    avatar: f.avatar || "default_avatar"
                })
            }
        }

        xhr.send()
    }

    function loadMessages(friendId) {
        message_model.clear()
        _chat_page.maxMessageId = 0

        var xhr = new XMLHttpRequest()
        xhr.open("GET", "http://127.0.0.1:10086/get_messages?user_id="
                 + _chat_page.currentUserId + "&friend_id=" + friendId + "&limit=100")
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE || xhr.status !== 200) return

            var messages
            try {
                messages = JSON.parse(xhr.responseText)
            } catch (e) {
                return
            }

            for (var i = 0; i < messages.length; i++) {
                var m = messages[i]
                message_model.append({
                    messageId: m.id,
                    text: m.content,
                    isMine: (m.from_user_id === _chat_page.currentUserId)
                })

                if (m.id > _chat_page.maxMessageId) {
                    _chat_page.maxMessageId = m.id
                }
            }

            dialogue_content.positionViewAtEnd()
        }
        xhr.send()
    }

    function loadConversations() {
        var xhr = new XMLHttpRequest()
        xhr.open("GET", "http://127.0.0.1:10086/conversations?user_id=" + _chat_page.currentUserId)
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE || xhr.status !== 200) return

            var conversations
            try {
                conversations = JSON.parse(xhr.responseText)
            } catch (e) {
                return
            }

            _chat_page.allConversations = conversations
            conversation_model.clear()

            for (var i = 0; i < conversations.length; i++) {
                var c = conversations[i]
                var timeStr = formatTime(c.last_time)
                conversation_model.append({
                    friendId: c.friend_id,
                    friendName: c.username,
                    avatar: c.avatar || "default_avatar",
                    lastTime: timeStr,
                    unreadCount: c.unread_count
                })
            }

            updateConversationBadge()
        }
        xhr.send()
    }

    // 标记对话已读
    function markConversationRead(friendId) {
        var xhr = new XMLHttpRequest()
        xhr.open("POST", "http://127.0.0.1:10086/mark_read")
        xhr.setRequestHeader("Content-Type", "application/x-www-form-urlencoded")
        xhr.send("user_id=" + _chat_page.currentUserId + "&friend_id=" + friendId)
    }

    // 更新 chat_icon 红点
    function updateConversationBadge() {
        var hasUnread = false
        for (var i = 0; i < conversation_model.count; i++) {
            if (conversation_model.get(i).unreadCount > 0) {
                hasUnread = true
                break
            }
        }
        _chat_page.hasUnreadMessages = hasUnread
    }

    // 更新本地对话模型
    function updateLocalConversation(friendId, friendName, friendAvatar) {
        // 在 conversation_model 中查找是否已有此对话
        var found = false
        for (var i = 0; i < conversation_model.count; i++) {
            if (conversation_model.get(i).friendId === friendId) {
                // 已有 -》 移到最前面，更新时间
                conversation_model.move(i, 0, 1)
                conversation_model.setProperty(0, "lastTime", "刚刚")
                // 自己发的消息，未读数不变（不需要改 unreadCount）
                found = true
                break
            }
        }
        if (!found) {
            // 新对话 -》 插入最前面
            conversation_model.insert(0, {
                friendId:    friendId,
                friendName:  friendName,
                avatar:      friendAvatar,
                lastTime:    "刚刚",
                unreadCount: 0
            })
        }
    }

    // 格式化时间
    function formatTime(timestampSec) {
        if (timestampSec === undefined || timestampSec === null || timestampSec === 0) return ""
        var dt = new Date(timestampSec * 1000)
        var now = new Date()
        var diffMs = now.getTime() - dt.getTime()
        var diffMin = Math.floor(diffMs / 60000)

        if (diffMin < 1) return "刚刚"
        if (diffMin < 60) return diffMin + "分钟前"

        var diffHour = Math.floor(diffMin / 60)
        if (diffHour < 24) return diffHour + "小时前"

        var diffDay = Math.floor(diffHour / 24)
        if (diffDay < 7) return diffDay + "天前"

        // 超过一周显示日期
        var month = dt.getMonth() + 1
        var day = dt.getDate()
        return month + "/" + day
    }

    Connections {
        target: search_edit

        function onTextChanged() {
            var keyword = search_edit.text.trim().toLowerCase()

            // chat_icon 模式：搜索对话
            if (chat_icon.selected) {
                conversation_model.clear()
                if (keyword === "") {
                    // 恢复完整对话列表
                    for (var k = 0; k < allConversations.length; k++) {
                        var c = allConversations[k]
                        conversation_model.append({
                            friendId: c.friend_id,
                            friendName: c.username,
                            avatar: c.avatar || "default_avatar",
                            lastTime: formatTime(c.last_time),
                            unreadCount: c.unread_count
                        })
                    }
                    return
                }

                for (var l = 0; l < allConversations.length; l++) {
                    var ac = allConversations[l]
                    if (ac.username.toLowerCase().indexOf(keyword) >= 0) {
                        conversation_model.append({
                            friendId: ac.friend_id,
                            friendName: ac.username,
                            avatar: ac.avatar || "default_avatar",
                            lastTime: formatTime(ac.last_time),
                            unreadCount: ac.unread_count
                        })
                    }
                }
                return
            }

            friend_model.clear()
            no_result_label.visible = false

            // 搜索框为空 → 恢复完整列表
            if (keyword === "") {
                no_result_label.text = "未找到匹配的好友"
                _chat_page.isSearchingNonFriend = false

                for (var i = 0; i < allFriends.length; i++) {
                    var f = allFriends[i]
                    friend_model.append({
                        userId: f.user_id,
                        username: f.username,
                        avatar: f.avatar || "default_avatar"
                    })
                }
                return
            }

            // 按关键字过滤
            var found = false
            for (var j = 0; j < allFriends.length; j++) {
                var af = allFriends[j]
                if (af.username.toLowerCase().indexOf(keyword) >= 0) {
                    friend_model.append({
                        userId: af.user_id,
                        username: af.username,
                        avatar: af.avatar || "default_avatar"
                    })

                    found = true
                }
            }

            // 无匹配结果
            if (!found) {
                no_result_label.visible = contact_icon.selected
            }
        }
    }

    FileDialog {
        id: avatar_file_dialog
        title: "选择头像图片"
        nameFilters: ["图片文件 (*.jpg *.jpeg *.png)"]
        fileMode: FileDialog.OpenFile

        onAccepted: {
            var newAvatar = avatarUploader.copyAndUpload(_chat_page.currentUserId, selectedFile)

            if (newAvatar !== "") {
                _chat_page.currentUserAvatar = ""        // ← 先清空
                _chat_page.currentUserAvatar = newAvatar // ← 再赋值
            }
        }
    }

    Rectangle {
        id: add_friend_popup
        width: 250
        height: 200
        radius: 8
        color: "white"
        visible: false
        z: 10
        x: (_chat_page.width - width) / 2
        y: (_chat_page.height - height) / 2

        // ========== 顶部拖动条 ==========
        Rectangle {
            id: popup_title_bar
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: 50
            color: "transparent"

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.ArrowCursor

                property real lastX: 0
                property real lastY: 0

                onPressed: (mouse) => {
                    lastX = mouse.x
                    lastY = mouse.y
                }

                onPositionChanged: (mouse) => {
                    add_friend_popup.x += mouse.x - lastX
                    add_friend_popup.y += mouse.y - lastY
                }
            }
        }
        // ===================================

        ColumnLayout {
            anchors.centerIn: parent
            spacing: 15

            Label {
                id: add_friend_target_name
                text: ""
                font.pixelSize: 16
                Layout.alignment: Qt.AlignHCenter
            }

            Label {
                id: add_friend_status
                text: "发送好友申请？"
                font.pixelSize: 13
                color: "#888888"
                Layout.alignment: Qt.AlignHCenter
            }

            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 20

                RoundButton {
                    Layout.preferredWidth: 60
                    Layout.preferredHeight: 25
                    text: "取消"
                    radius: 4
                    onClicked: add_friend_popup.visible = false
                }

                RoundButton {
                    Layout.preferredWidth: 60
                    Layout.preferredHeight: 25
                    text: "确定"
                    radius: 4

                    onClicked: {
                        add_friend_status.text = "发送中..."
                        add_friend_status.color = "#4A90D9"

                        var addXhr = new XMLHttpRequest()
                        addXhr.open("POST", "http://127.0.0.1:10086/add_friend")
                        addXhr.setRequestHeader("Content-Type", "application/x-www-form-urlencoded")

                        addXhr.onreadystatechange = function() {
                            if (addXhr.readyState !== XMLHttpRequest.DONE) return

                            // 情况1：服务器未启动
                            if (addXhr.status === 0) {
                                add_friend_status.text = "服务器连接失败"
                                add_friend_status.color = "red"
                                return
                            }

                            // 情况2：申请成功
                            if (addXhr.status === 201) {
                                add_friend_status.text = "好友申请已发送"
                                add_friend_status.color = "green"
                                return
                            }

                            // 情况3：冲突
                            if (addXhr.status === 409) {
                                add_friend_status.text = "已是好友或已有待处理申请"
                                add_friend_status.color = "red"
                                return
                            }

                            // 情况4：其他错误
                            add_friend_status.text = "操作失败 (错误码: " + addXhr.status + ")"
                            add_friend_status.color = "red"
                        }

                        addXhr.send("user_id=" + encodeURIComponent(_chat_page.currentUserId)
                                    + "&friend_id=" + encodeURIComponent(addFriendTargetId))
                    }
                }
            }
        }
    }

    Timer {
        id: pending_check_timer
        interval: 1000
        repeat: true
        running: _chat_page.currentUserId > 0

        onTriggered: {
            var checkXhr = new XMLHttpRequest()
            checkXhr.open("GET", "http://127.0.0.1:10086/pending_count?user_id=" + _chat_page.currentUserId)
            checkXhr.onreadystatechange = function() {
                if (checkXhr.readyState === XMLHttpRequest.DONE && checkXhr.status === 200) {
                    var resp = JSON.parse(checkXhr.responseText)
                    _chat_page.hasPendingRequest = (resp.count > 0)
                }
            }
            checkXhr.send()
        }
    }

    Timer {
        id: friend_list_refresh_timer
        interval: 5000
        repeat: true
        running: _chat_page.currentUserId > 0 && search_edit.text === ""

        onTriggered: {
            loadFriendList()
        }
    }

    Timer {
        id: message_poll_timer
        interval: 2000
        repeat: true
        running: _chat_page.currentUserId > 0 && _chat_page.selectedFriendId > 0 && !_chat_page.sending

        onTriggered: {
            if (_chat_page.selectedFriendId <= 0) return

            var xhr = new XMLHttpRequest()
            xhr.open("GET", "http://127.0.0.1:10086/get_messages?user_id="
                     + _chat_page.currentUserId
                     + "&friend_id=" + _chat_page.selectedFriendId
                     + "&after_id=" + _chat_page.maxMessageId
                     + "&limit=100")
            xhr.onreadystatechange = function() {
                if (xhr.readyState !== XMLHttpRequest.DONE || xhr.status !== 200) return

                var messages
                try {
                    messages = JSON.parse(xhr.responseText)
                } catch (e) {
                    return
                }

                if (messages.length === 0) return

                for (var i = 0; i < messages.length; i++) {
                    var m = messages[i]
                    message_model.append({
                        messageId: m.id,
                        text: m.content,
                        isMine: (m.from_user_id === _chat_page.currentUserId)
                    })

                    if (m.id > _chat_page.maxMessageId) {
                        _chat_page.maxMessageId = m.id
                    }
                }
            }

            xhr.send()
        }
    }

    Timer {
        id: conversation_poll_timer
        interval: 5000
        repeat: true
        running: _chat_page.currentUserId > 0

        onTriggered: {
            loadConversations()
        }
    }
}
