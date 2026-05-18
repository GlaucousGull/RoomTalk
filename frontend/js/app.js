let user_data = null;
let current_joining_room = null;
let room_list = [];
let waitAckMap = {} //消息等待确认池

let lastServerResponseTime = Date.now();
let heartbeatTimer = null;      // 心跳定时器
let reconnectTimeOut = null;    // 重连定时器
const HEARTBEAT_INTERVAL = 30000;  // 30秒心跳

// 连接函数
function connectWebSocket() {
    const wsUrl = "ws://" + window.location.hostname + ":10000";
    ws = new WebSocket(wsUrl);

    // 连接建立
    ws.onopen = function() {
        console.log("WebSocket 连接成功");

        // 清空重连定时器
        if (reconnectTimeOut) clearTimeout(reconnectTimeOut);

        // 发送房间同步指令
        ws.send(JSON.stringify({ type: "synchro_room_list" }));

        stopHeartbeat();

        //  启动心跳定时器
        startHeartbeat();
    };

    // 监听后端发来的消息
    ws.onmessage = function(evt) {
        const data = JSON.parse(evt.data);
        console.log("后端返回：", data);
        lastServerResponseTime = Date.now();    // 刷新服务最后一次发送时间


        // 处理后端返回的消息
        switch(data.type) {
            case "init_user":
                user_data = {
                    user_id: data.data.user_id,
                    user_name: data.data.user_name
                };
                // 更新用户信息
                document.getElementById("displayUserName").innerText = user_data.user_name;
                document.getElementById("displayUserId").innerText = `UID: ${user_data.user_id.slice(-6)}`;
                break;

            case "create_room_success":
                room_list.push({
                    room_id: data.data.room_id,
                    room_type: data.data.room_type,
                    room_name: data.data.room_name,
                });
                renderRoomList();
                alert("创建房间成功！");
                break;

            case "create_room_fail":
                alert("创建房间失败");
                break;

            case "room_list":
                room_list = data.data.rooms;
                renderRoomList();
                break;

            case "join_room_success":
                document.querySelector(".right-chat-area").classList.add("show")
                // 加载历史消息
                load_history_messages(data.data.his_msg);
                break;

            case "join_room_fail":
                alert(`加入失败：${data.data.msg || "未知错误"}`);
                break;

            case "new_message":
                new_message_processing(data.data);
                break;

            case "heartbeat_ack":
                // 清除定时器的任务
                break;
            
            case "room_users":
                roomOnlineUsersRendering(data.data);
                break;
        }
    };


    // 连接关闭 -> 自动重连
    ws.onclose = function () {
        console.log("连接断开，尝试重连中");
        stopHeartbeat();    //
        scheduleReconnect(); // 自动重连
    }

    // 连接错误
    ws.onerror = function (err) {
        console.log("webSocket错误", err);
    }
}

// 心跳发送
function startHeartbeat() {
    heartbeatTimer = setInterval(() => {
        if (ws.readyState === WebSocket.OPEN) {
            // 发送心跳包
            ws.send(JSON.stringify({
                type: "heartbeat"
            }));
            console.log("心跳发送")
        }
    }, HEARTBEAT_INTERVAL);
}

// 超时检测
function startTimeoutCheck() {
    timeoutTimer = setTimeout(() => {
        // 获取当前时间戳
        const now = Date.now();
        // 计算超时
        if (now - lastServerResponseTime > HEARTBEAT_INTERVAL) {
            console.log("服务器超时无响应，重连中...")
            // 启动重连定时器
            scheduleReconnect();
        }
    })
}

// 停止心跳
function stopHeartbeat() {
    if (heartbeatTimer) {
        clearInterval(heartbeatTimer);
        heartbeatTimer = null;  // 清空变量，防止旧引用
    }
}

// 自动重连
function scheduleReconnect() {
    if (reconnectTimeOut) clearTimeout(reconnectTimeOut);   //防止重连叠加
    ws.close();
    reconnectTimeOut = setTimeout(() => {
        connectWebSocket();
    }, 3000);
}

// 新消息广播处理
function new_message_processing(data) {
    msg_id = data.msg_id;

    if (user_data.user_id == data.user_id) {
        // 自己发送的消息，不渲染，并清除消息超时任务
        if (waitAckMap[msg_id]) {
            clearTimeout(msg_id);
            delete waitAckMap[msg_id];
        }
        return;
    }

    // 追加消息
    append_single_message(data);
}

// 启动
connectWebSocket();

// 房间点击绑定以及渲染列表
function renderRoomList() {
    const ul = document.getElementById("room_list");
    ul.innerHTML = "";
    room_list.forEach(room => {
        const li = document.createElement("li");
        const icon = room.room_type == 1 ? "🔒" : "💬";
        li.innerText = `${icon} 房间号：${room.room_id} | ${room.room_name}`;
        li.onclick = () => handleRoomClick(room);
        ul.appendChild(li);
    });
}

// 处理房间点击事件
function handleRoomClick(room) {
    if (!user_data) { alert("用户信息未加载"); return; }
    current_joining_room = room;

    if (room.room_type == 1) {
        document.getElementById("pwdModal").style.display = "flex";
        // 获取用户输出的密码
    } else {
        ws.send(JSON.stringify({
            type: "join_room",
            data: {
                room_id: room.room_id,
                user_id: user_data.user_id
            }
        }));
    }
}

// 关闭密码弹窗
function closePwdModal() {
    document.getElementById("pwdModal").style.display = "none";
    document.getElementById("roomPwdInput").value = "";
    current_joining_room = null;
}

// 私域房间确认密码
document.getElementById("confirmPwdBtn").onclick = function() {
    const pwd = document.getElementById("roomPwdInput").value.trim();
    if (!pwd) return alert("请输入密码");

    ws.send(JSON.stringify({
        type: "join_room",
        data: {
            room_id: current_joining_room.room_id,
            password: pwd,
            user_id: user_data.user_id
        }
    }));
    closePwdModal();
};

// 取消
document.getElementById("cancelPwdBtn").onclick = closePwdModal;

// 创建房间
const modal = document.getElementById("createModal");
document.getElementById("createRoomBtn").onclick = () => modal.style.display = "flex";
function closeModal() { modal.style.display = "none"; }

// 监听选择房间的类型
document.getElementById("roomTypeSelBtn").addEventListener("change", function() {
    const roomType = this.value;
    document.getElementById("roomPasswordInputWrap").style.display = roomType == "1" ? "block" : "none";
})

// 创建房间
function createRoom() {
    if (!user_data) return alert("请等待用户初始化");
    // 区分用户创建的房间类型
    room_name_value = document.getElementById("roomName").value.trim(),
    room_type_value = document.getElementById("roomTypeSelBtn").value
    switch(room_type_value) {
        case "0": 
            ws.send(JSON.stringify({
                type: "create_room",
                data: {
                    user_id: user_data.user_id,
                    room_name: room_name_value,
                    room_type: room_type_value
                }}));
                break;
        case "1":
            // 获取私域房间的密码
            password = document.getElementById("roomPasswordInput").value.trim();
            if(!password) {
                alert("私域房间必须设置密码");
                return;
            }
            ws.send(JSON.stringify({
                type: "create_room",
                data: {
                    user_id: user_data.user_id,
                    room_name: room_name_value,
                    room_type: room_type_value,
                    password: password
                }}));
                break;
    }

    closeModal();
    document.getElementById("roomName").value = "";
    document.getElementById("roomPasswordInput").value = "";
    document.getElementById("roomTypeSelBtn").value = "0";
}

// 刷新
document.getElementById("refreshBtn").onclick = () => {
    ws.send(JSON.stringify({ type: "synchro_room_list" }));
};

// 加载房间历史消息
function load_history_messages(msgList) {
    const chatHistory = document.getElementById("chatHistory");
    // 进来先清空原有消息
    chatHistory.innerHTML = "";
    if (!Array.isArray(msgList)) { console.warn("不是数组"); return; }
    msgList.forEach(item => append_single_message(item));
}

// 渲染单条消息
function append_single_message(msg) {
    // 信息是是个三元组 {用户id， 用户名，消息}
    isSelf = (msg.user_id == user_data.user_id);

    // 取用户名最后字符当成用户的头像
    const avatarText = msg.user_name.charAt(0);

    // 获取消息区盒子
    const charHigstory = document.getElementById("chatHigstory");

    // 拼接消息
    const msgHtml = `
        <div class="msg-item ${isSelf ? 'self-msg' : 'other-msg'}" data-msg-id="${msg.msg_id}">
            <div class="msg-avatar">${avatarText}</div>
            <div class="msg-content">
                <div class="msg-name">${msg.user_name}</div>
                <div class="msg-bubble">${msg.body}</div>
            </div>
        </div>
    `;

    //  追加到消息区
    chatHistory.innerHTML += msgHtml;
    // 滚动到底部
    chatHistory.scrollTop = chatHistory.scrollHeight;
}

// 可拖动逻辑（LeetCode效果）
const leftSidebar = document.getElementById('leftSidebar');
const dragDivider = document.getElementById('dragDivider');
let isDragging = false;

dragDivider.addEventListener('mousedown', (e) => {
    isDragging = true;
    document.body.style.cursor = 'col-resize';
    e.preventDefault();
});

document.addEventListener('mousemove', (e) => {
    if (!isDragging) return;
    let w = e.clientX;
    if (w < 220) w = 220;
    if (w > 450) w = 450;
    leftSidebar.style.width = w + 'px';
});

document.addEventListener('mouseup', () => {
    isDragging = false;
    document.body.style.cursor = 'default';
});

// 消息发送
function sendMessage() {
    // 获取消息文本框数据
    const input = document.getElementById("msgInput");
    const content = input.value;

    // 消息判断
    if (!content.trim()){
        // 空白内容，直接不处理
        return;
    }

    // 生成消息id
    msg_id = "msg_" + Date.now() + Math.random();

    append_single_message({
        user_id: user_data.user_id,
        user_name: user_data.user_name,
        body: content,
        msg_id: msg_id
    })

    // 发送原始内容
    ws.send(JSON.stringify({
        type: "send_message",
        data: {
            user_id: user_data.user_id,
            room_id: current_joining_room.room_id,
            msg: content,
            msg_id: msg_id
        }
    }));

    if (!waitAckMap) {
        waitAckMap = {};
    }

    // 消息确认池添加消息超时检测方法
    const timer = setTimeout(() => {
        if (typeof markMessageFailed == "function") {
            markMessageFailed(msg_id);
        }
        delete waitAckMap[msg_id];
    }, 5000);

    // 添加超时处理任务
    waitAckMap[msg_id] = timer;

    // 发送后清空输入文本框
    input.value = "";
}

// 消息发送失败
function markMessageFailed(msg_id) {
    // 找到对应消息元素，添加失败样式
    const msgItem = document.querySelector(`.msg-item[data-msg-id="${msg_id}"]`);
    if (msgItem) return;
    if (!msgItem) {
        console.log("没有找到消息，可能已被删除");
        return;
    }
    // 找到气泡
    const buttle = msgItem.querySelector(".msg-buttle");
    if (!buttle) {
        console.log("没有找到消息，可能已被删除");
        return;
    }
    // 标红样式
    msgItem.style.opacity = "0.8";
    bubble.style.background = "#ff4444";
    bubble.style.color = "#fff";

    // 前面加感叹号 ❗
    bubble.innerText = "❗" + bubble.innerText;
}

//等待页面加载完成，再绑定事件
window.onload = function() {
    document.getElementById("sendBtn").onclick = sendMessage;

    document.getElementById("msgInput").onkeydown = (e) => {
        if (e.key == "Enter") {
            e.preventDefault(); // 防止输入框换行
            sendMessage();
        }
    };
};

// 视频通话响应逻辑所需信息
let currentRoomId = "";
let targetCallUserId = "";
let targetCallUserNmae = "";

document.getElementById("openCallSelectBtn").addEventListener("click", async () => {
    console.log("视频通话按钮被点击");

    // 1. 先打印所有变量，确认它们的值
    console.log("current_joining_room:", current_joining_room);
    currentRoomId = current_joining_room?.room_id;
    console.log("currentRoomId:", currentRoomId);
    console.log("user_data:", user_data);
    console.log("user_id:", user_data?.user_id);

    // 2. 前置校验
    if (!currentRoomId || currentRoomId === "") {
        alert("未加入房间，视频通话请求失败");
        return;
    }
    if (!user_data || !user_data.user_id) {
        alert("用户未登录，无法发起请求");
        return;
    }
    if (!ws || ws.readyState !== WebSocket.OPEN) {
        alert("网络连接异常，请稍后重试");
        console.log("ws状态:", ws?.readyState);
        return;
    }

    console.log("所有校验通过，准备发送消息");

    // 3. 构建消息，先打印再序列化，确保内容正常
    const msg = {
        type: "get_room_online_users",
        data: {
            user_id: user_data.user_id,
            room_id: currentRoomId
        }
    };
    console.log("准备发送的消息对象:", msg);

    // 4. 加 try-catch 捕获序列化和发送的异常
    try {
        const str = JSON.stringify(msg);
        console.log("序列化后的消息:", str);
        ws.send(str);
        console.log("消息发送成功");
        document.getElementById("callUserModal").style.display = "block";
    } catch (err) {
        console.error("发送消息时出错:", err);
        alert("发送失败: " + err.message);
    }
});

// 关闭通话列表弹窗
document.getElementById("closeCallModal").addEventListener("click", () => {
    document.getElementById("callUserModal").style.display = "none";
});

// 接收后端发来的用户列表并在通话界面渲染
function roomOnlineUsersRendering(data) {
    const ulDom = document.getElementById("onlineUserList");
    ulDom.innerHTML = "";
    user_list = data.user_list;
    user_list.forEach(item => {
        online_state = item.user_online;
        if (online_state == false
            || online_state == "false"
            || online_state == "0"
            || item.user_id == user_data.user_id) {
            return;
        }
        let li = document.createElement("li");
        li.style.padding = "8px 0";
        li.style.cursor = "pointer";
        li.style.borderBottom = "1px solid #eee";
        li.innerText = item.user_name;
        // 点击选中发起邀请事件绑定
        li.addEventListener("click", () => {
            targetCallUserId = item.user_id;
            targetCallUserNmae = item.user_name;
            // 关闭选择弹窗
            document.getElementById("callUserModal").style.display = "none";
            // 向后端发起通话请求
            ws.send(JSON.stringify({
                type: "invite_video_call",
                data: {
                    invater_id: user_data.user_id,
                    target_id: targetCallUserId,
                    room_id: current_joining_room.room_id
                }
            }));
        })

        ulDom.appendChild(li);
    })
}

// 显示来电
function showIncomingCall(userName) {
    document.getElementById("callUserNmae").innerText = userName;
    document.getElementById("incomigCallModal").style.display = "block";
}

// 隐藏来电
function hideIncomingCall() {
    document.getElementById("incomigCallModal").style.display = "none";
}

// 同意
document.getElementById("acceptCall").onclick = function() {
    hideIncomingCall();
}

// 拒绝
document.getElementById("rejectCall").onclick = function() {
    hideIncomingCall();
}

// webRTC实现视频通话
let localStream;
let peerConnection;

// 打开摄像头
async function startCamera() {
    localStream = await nevigator.mediaDevices.getUserMedia({
        video: true,
        Audio: true
    });

    // 绑定视频通话按钮
    // document.
}

// 