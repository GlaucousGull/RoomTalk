// chat.js
let user_data = null;
let current_joining_room = null;
let room_list = [];
let waitAckMap = {} //消息等待确认池

let lastServerResponseTime = Date.now();
let heartbeatTimer = null;      // 心跳定时器
let reconnectTimeOut = null;    // 重连定时器
const HEARTBEAT_INTERVAL = 30000;  // 30秒心跳

let callInstace = null; // 音视频通话实例

// 连接函数
function connectWebSocket() {
    // 自动根据当前浏览器地址拼接 WebSocket 地址
    const protocol = window.location.protocol === "https:" ? "wss:" : "ws:";
    const wsUrl = `${protocol}//${window.location.hostname}:10000/ws`;
    ws = new WebSocket(wsUrl);

    // 连接建立
    ws.onopen = function() {
        console.log("WebSocket 连接成功");

        // 清空重连定时器
        if (reconnectTimeOut) clearTimeout(reconnectTimeOut);

        // 发送用户上线指令
        ws.send(JSON.stringify({ type: "user_login",
            data: {
                "account": localStorage.getItem("account"),
                "user_id": localStorage.getItem("uid"),
                "user_name": localStorage.getItem("username")
            }
        }));

        // 发送房间同步指令
        ws.send(JSON.stringify({ type: "synchro_room_list" }));

        stopHeartbeat();

        // 启动心跳定时器
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
                    account: data.data.account,
                    user_id: data.data.user_id,
                    user_name: data.data.user_name
                };
                // 更新用户信息
                document.getElementById("displayUserName").innerText = user_data.user_name;
                document.getElementById("displayUserId").innerText = `UID: ${user_data.user_id.slice(-6)}`;

                // 初始化音视频通话
                VideoCall.init(ws, user_data);
                break;
            case "init_user":
                alert(data.data.msg);
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
                console.log("roomid: ", data.data.room_id, "roomNmae", data.data.room_name);
                current_joining_room = {
                    room_id: data.data.room_id,
                    room_name: data.data.room_name
                };

                // 渲染顶部房间名等状态
                enterRoom(data.data.room_name, data.data.online_users);

                document.querySelector(".right-chat-area").classList.add("show")
                // 加载历史消息
                load_history_messages(data.data.his_msg);

                // 创建视频通话实例
                if (current_joining_room && current_joining_room.room_id) {
                    callInstace = new VideoCall({
                        userId: user_data.user_id,
                        roomId: current_joining_room.room_id
                    });
                }else {
                    console.error("未加入房间，无法初始化视频通话！");
                    alert("请先加入一个房间！");
                }

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
                // alert("获取到房间内的用户列表");
                callInstace.renderOnlineUserList(data.data.user_list);
                break;

            case "ice_config":
                // alert("获取到服务器配置的公共ICE地址");
                VideoCall.setIceUrl(data.data.ice_servers);
                break;

            case "avideo_call_invite":
                alert("收到其他用户的音视频通话邀请");
                callInstace.setPeerUserData(data.data.inviter_id, data.data.inviter_name)
                callInstace.setAvdioSdp(data.data.sdp);
                callInstace.setPeerRoomId(data.data.room_id);
                VideoCall.showIncomingCall(data.data.user_name, data.data.room_name);
                break;

            case "avideo_call_fail":
                alert(data.data.msg);
                break;

            case "answer":
                callInstace.processRemoteAnswer(data.data.sdp);
                console.log("接收到接收返回的 answer");
                break;

            case "remote_ice_candidate":
                callInstace.addRemoteIceCandidate(data.data.candidate);
                break;
            
            default:
                console.log("为未匹配到 %s 事件名", data.type);
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

// 房间名加载和房间人数加载
function enterRoom(roomName, roomCount) {
    document.getElementById("roomName").innerText = roomName;
    document.getElementById("userCount").innerText = `(在线${roomCount}人`;
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
    // current_joining_room = null;
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
    room_name_value = document.getElementById("roomNameInput").value.trim(),
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
    document.getElementById("roomNameInput").value = "";
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

class VideoCall {
    // 静态成员（类级别）
    static iceConfig = null;
    static iceLoaded = false;
    static ws = null;           // 绑定 websocket
    static userData = null;     // 当前用户信息
    

    // 私有实例成员
    #localStream;       // 本地音视频流
    #userId;            // 自己ID
    #targetId;          // 对方ID
    #targetName;        // 对方名字
    #roomId;            // 当前房间ID
    #peerRoomId;        // 对方房间ID
    #pc;                // RTCPeerConnection
    #sdp = null;        // 音视频通话 sdp: offer
    #video = true;
    #audio = true;

    // 构造函数
    constructor({ userId, targetId = null, targetName = '', roomId, video = true, audio = true }) {
        this.#userId = userId;
        this.#targetId = targetId;
        this.#targetName = targetName;
        this.#roomId = roomId;
        this.#video = video;
        this.#audio = audio;
        this.#localStream = null;

        // 绑定 DOM 事件（只绑定一次）
        this.#bindEvents();
    }

    // 静态初始化
    static init(wsInstance, userData) {
        VideoCall.ws = wsInstance;
        VideoCall.userData = userData;

        // 页面加载就获取 ICE 配置
        VideoCall.getIceUrl();
    }

    // 静态：请求 ICE 配置
    static getIceUrl() {
        console.log("用户请求ICE配置");
        if (!VideoCall.ws) return;
        VideoCall.ws.send(JSON.stringify({ type: "get_ice_url", data: {} }));
    }

    // 静态：设置 ICE 配置
    static setIceUrl(data) {
        VideoCall.iceConfig = data.map(item => ({ urls: item.url }));
        VideoCall.iceLoaded = true;
    }

    // 静态：显示来电弹窗
    static showIncomingCall(userName, room_name) {
        document.getElementById("inviteUserName").innerText = "邀请人：" + userName;
        document.getElementById("inviteText").textContent = "房间：" + room_name;
        document.getElementById("callInviteModal").style.display = "block";
    }

    // 静态：关闭来电弹窗
    static hideIncomingCall() {
        document.getElementById("callInviteModal").style.display = "none";
    }

    // 私有：绑定所有 DOM 事件
    #bindEvents() {
        // 打开视频通话选择
        document.getElementById("openCallSelectBtn").onclick = () => {
            this.#onOpenCallListClick();

        };

        // 关闭选择弹窗
        document.getElementById("closeCallModal").onclick = () => {
            document.getElementById("callUserModal").style.display = "none";
        };

        // 同意通话
        document.getElementById("agreeCallBtn").onclick = () => {
            console.log("点击同意通话");
            VideoCall.hideIncomingCall();
            this.#handleAcceptCall();
        };

        // 拒绝通话
        document.getElementById("refuseCallBtn").onclick = () => {
            console.log("点击拒绝通话");
            VideoCall.hideIncomingCall();
            this.#handleRejectCall();
        };

        // 挂断视频通话
        document.getElementById("hangupBtn").onclick = function() {
            if (callInstace) {
                callInstace.hangup();   // 断开连接
            }
            VideoCall.hideIncomingCall();     // 下沉通话界面
            console.log("已挂断电话");
        }
    }

    // 挂断电话
    hangup() {
        try {
            // 关闭p2p连接
            if (this.#pc) {
                this.#pc.close();
                this.#pc = null;
            }

            // 关闭摄像头和摄像头和麦克风
            if (this.#localStream) {
                this.#localStream.getTracks().forEach(track => {
                    track.stop();   // 关闭每个轨道：画面采集、音频采集
                });
                this.#localStream = null;
            }
        } catch (e) {
            console.log("挂断出错", e);
        }

        // 隐藏视频界面
        const videoContainer = document.getElementById("videoContainer");
        if (videoContainer) {
            videoContainer.style.display = "none";
        }

        // 清空 video 标签画面
        const localVideo = document.getElementById("localVideo");
        const remoteVideo = document.getElementById("remoteVideo");
        if (localVideo) localVideo.srcObject = null;
        if (remoteVideo) remoteVideo.srcObject = null;

        console.log("已挂断：连接关闭 + 摄像头/麦克风已停止");
    }

    // 设置对端用户信息
    setPeerUserData(user_id, user_name) {
        this.#targetId = user_id;
        this.#targetName = user_name;
    }

    // 设置对端房间信息
    setPeerRoomId(peerRoomId) {
        this.#peerRoomId = peerRoomId;
    }

    // 设置sdp
    setAvdioSdp(sdp) {
        this.#sdp = sdp;
    }

    // 打开通话列表
    #onOpenCallListClick() {
        if (!this.#roomId) return alert("未加入房间");
        if (!VideoCall.userData) return alert("未登录");
        VideoCall.ws.send(JSON.stringify({
            type: "get_room_online_users",
            data: {
                user_id: VideoCall.userData.user_id,
                room_id: this.#roomId
            }
        }));
        document.getElementById("callUserModal").style.display = "block";
    }

    // 渲染在线用户列表
    renderOnlineUserList(userList) {
        const ul = document.getElementById("onlineUserList");
        ul.innerHTML = "";
        userList.forEach(item => {
            if (!item.user_online || item.user_id === VideoCall.userData.user_id) return;
            const li = document.createElement("li");
            li.innerText = item.user_name;
            li.style.padding = "8px 0";
            li.style.cursor = "pointer";
            li.onclick = async () => {
                // 获取本地媒体流
                await this.#getLocalStream();

                this.#targetId = item.user_id;
                this.#targetName = item.user_name;
                document.getElementById("callUserModal").style.display = "none";

                // 先创建连接 → 再发offer
                await this.createPeerConnection();
                await this.sendOffer();
            };
            ul.appendChild(li);
        });
    }

    // 创建 P2P 连接
    async createPeerConnection() {
        if (!VideoCall.iceLoaded) {
            console.error("ICE 未加载");
            return;
        }

        document.getElementById("videoContainer").style.display = "block";

        // 创建连接
        this.#pc = new RTCPeerConnection({ iceServers: VideoCall.iceConfig });
        console.log("创建 RTCPeerConnection 成功");

        // 添加轨道
        if (!this.#localStream) {
            console.error(" 本地流不存在，无法添加轨道");
        }else {
            this.#addLocalTracks();
            console.log("添加本地轨道完成")
        }

        // ontrack 监听远程流
        this.#pc.ontrack = (e) => {
            console.log("收到远程流", e.streams[0]);
            
            const remoteVideo = document.getElementById("remoteVideo");
            if (!remoteVideo) {
                console.error(" 找不到 remoteVideo 元素");
                return;
            }

            // 只赋值一次，避免重复覆盖导致播放中断
            if (!remoteVideo.srcObject) {
                remoteVideo.srcObject = e.streams[0];
                console.log("远程流已绑定到 video");
            }

            // 安全播放
            remoteVideo.play().catch(err => {
                console.warn("视频自动播放被浏览器限制（不影响功能）", err);
            });
        };

        // 发送 ICE 候选者
        this.#pc.onicecandidate = (e) => {
            if (e.candidate) {
                console.log("发送本地ICE:", e.candidate);
                VideoCall.ws.send(JSON.stringify({
                    type: "local_ice_candidate",
                    data: {
                        target_id: this.#targetId,
                        candidate: e.candidate
                    }
                }));
            }
        };

        // 状态监听（排查用）
        this.#pc.oniceconnectionstatechange = () => {
            console.log("ICE 状态：", this.#pc.iceConnectionState);
        };

        this.#pc.onconnectionstatechange = () => {
            console.log("连接状态：", this.#pc.connectionState);
        };
    }

    // 接收对方发来的 ice_candidate
    async addRemoteIceCandidate(candidate) {
        try {
            await this.#pc.addIceCandidate(new RTCIceCandidate(candidate));
            console.log("添加远程 ICE 成功", candidate);
        } catch (err) {
            console.error("添加 ICE 失败：", err, candidate);
        }
    }

    // 获取本地流
    async #getLocalStream() {
        // 已经获取过，不在获取
        if (this.#localStream) return;
        if (!navigator.mediaDevices) {
            alert("请使用 localhost/htpps 访问，否则无法打开摄像头");
            throw new Error("不支持媒体设备");
        }
        try {
            this.#localStream = await navigator.mediaDevices.getUserMedia({
                video: true,
                audio: {
                    echoCancellation: true,     // 开启回声消除
                    noiseSuppression: true,     // 开启噪音音质
                    autoGainControl: true       // 开启自动增益控制，稳定音量
                }
            });
    
            const localVideo = document.getElementById("localVideo");
            if (localVideo) localVideo.srcObject = this.#localStream;

        } catch (err) {
            alert("请允许摄像头/麦克风权限");
            throw err;
        }
    }

    // 添加本地轨道
    #addLocalTracks() {
        if (!this.#localStream || !this.#pc) return;
        this.#localStream.getTracks().forEach(track => {
            this.#pc.addTrack(track, this.#localStream);
            console.log("添加本地轨道：", track.kind);
        });
    }

    // 核心流程：发起方 → 发送 Offer
    async sendOffer() {
        const offer = await this.#pc.createOffer({
            offerToReceiveVideo: true,
            offerToReceiveAudio: true
        });
        await this.#pc.setLocalDescription(offer);
        VideoCall.ws.send(JSON.stringify({
            type: "offer",
            data: {
                inviter_id: this.#userId,
                target_id: this.#targetId,
                room_id: this.#roomId,
                sdp: offer
            }
        }));
        console.log("发起方发送 offer 成功");
    }

    // 接收方处理流程：
    async #handleAcceptCall() {
        try {
            console.log("开始处理接听流程");

            // 获取本地流（必须在点击事件里第一时间获取，避免权限问题）
            await this.#getLocalStream();
            console.log("本地流获取成功");

            // 创建连接
            await this.createPeerConnection();
            console.log("PeerConnection 创建成功");

            // 设置远程 Offer SDP（必须包装成 RTCSessionDescription）
            if (!this.#sdp || !this.#sdp.type || !this.#sdp.sdp) {
                throw new Error("收到的 Offer SDP 格式错误");
            }
            const remoteDesc = new RTCSessionDescription(this.#sdp);
            await this.#pc.setRemoteDescription(remoteDesc);
            console.log("setRemoteDescription 成功");

            // 创建并发送 Answer
            const answer = await this.#pc.createAnswer();
            await this.#pc.setLocalDescription(answer);
            console.log("setLocalDescription 成功");

            // 发送 Answer 给对方
            VideoCall.ws.send(JSON.stringify({
                type: "answer",
                data: { target_id: this.#targetId, sdp: answer }
            }));
            console.log("已发送 Answer");

            // 显示视频容器
            document.getElementById("videoContainer").style.display = "block";

        } catch (e) {
            console.error("接听失败，完整错误信息：", e);
            alert("接听失败：" + e.message);
        }
    }

    // 核心流程：发起方 → 收到 Answer
    async processRemoteAnswer(sdp) {
        if (!this.#pc) {
            console.log("processRemoteAnswer:pc 不存在，创建中");
            await this.createPeerConnection();
        }
        await this.#pc.setRemoteDescription(new RTCSessionDescription(sdp));
        console.log("发起方设置远程");

    }

    // 拒绝
    #handleRejectCall() {
        VideoCall.ws.send(JSON.stringify({
            type: "reject_video_call",
            data: { target_id: this.#targetId }
        }));
    }
}