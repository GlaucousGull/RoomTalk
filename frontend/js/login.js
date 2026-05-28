// 状态定义
const AUTH_STATE = {
    LOGIN: "login",
    REGISTER: "register",
    REGISTER_SUCCESS: "register_success"
};

// 当前状态
let currentState = AUTH_STATE.LOGIN;

/**
 * 状态机核心函数：切换到指定状态
 * @param {string} newState - 目标状态
 */
function changeState(newState) {
    // 页面切换逻辑如下：
    // 先给所有页面设计隐藏属性
    // 然后根据传入的状态，移除隐藏属性
    // 这样就可以让对应的页面显示出来
    // 隐藏所有面板
    document.getElementById("loginPanel").classList.add("hidden");
    document.getElementById("registerPanel").classList.add("hidden");
    document.getElementById("registerSuccessPanel").classList.add("hidden");

    // 根据新状态显示对应的面板
    switch (newState) {
        case AUTH_STATE.LOGIN:
            document.getElementById("loginPanel").classList.remove("hidden");
            break;
        case AUTH_STATE.REGISTER:
            document.getElementById("registerPanel").classList.remove("hidden");
            break;
        case AUTH_STATE.REGISTER_SUCCESS:
            document.getElementById("registerSuccessPanel").classList.remove("hidden");
            break;
    }

    // 更新当前状态
    currentState = newState;
}

// 事件调用方法：注册页
function goToRegister() {
    console.log("【DOM事件】立即注册被点击");
    changeState(AUTH_STATE.REGISTER);
}
// 事件调用方法：登录页
function goToLogin() {
    changeState(AUTH_STATE.LOGIN);
}

/**
 * 登录请求
 */
async function doLogin() {
    try {
        const account = document.getElementById("loginUser").value;
        const pwd = document.getElementById("loginPwd").value;
    
        const res = await fetch("/api/login", {
            method: "POST",
            headers: {
                "Content-Type": "application/json"
            },
            body: JSON.stringify({
                account: account,
                password: pwd
            })
        });
    
        const data = await res.json();
    
        switch (data.code) {
            case 1001:
                // 登录成功,记录账号,uid,用户名
                const {account, uid, username} = data.body;
                localStorage.setItem("account", account);
                localStorage.setItem("uid", uid);
                localStorage.setItem("username", username);
                alert("欢迎登录");
                location.href = "/pages/chat.html";
                break;
            case 1002:
                // 登录失败
                alert("登录失败" + data.body.reason);
                break;
        }
    } catch (err) {
        alert("网络请求异常");
    }
}

/**
 * 注册请求
 */
async function doRegister() {
    try {
        const nickname = document.getElementById("regUser").value;
        const pwd = document.getElementById("regPwd").value;
    
        const res = await fetch("/api/register", {
            method: "POST",
            headers: {
                "Content-Type": "application/json"
            },
            body: JSON.stringify({
                nickname: nickname,
                password: pwd
            })
        });
    
        const data = await res.json();

        switch (data.code) {
            case 1003:
                showRegisterSuccess(data.body.account);
                break;
            case 1004:
                alert("注册失败");
                break;
        }
    } catch (err) {
        alert("网络请求异常");
    }
}

/**
 * 显示注册成功面板
 * @param {string} account - 后端生成的账号
 */
function showRegisterSuccess(account) {
    document.getElementById("showAccount").textContent = account;
    changeState(AUTH_STATE.REGISTER_SUCCESS);
}

/**
 * 复制账号到剪贴板
 */
function copyAccount() {
    const accountText = document.getElementById("showAccount").textContent;
    if (!accountText) {
        alert("没有可复制的账号");
        return;
    }

    // 优先使用 navigator.clipboard API
    if (navigator.clipboard && navigator.clipboard.writeText) {
        navigator.clipboard.writeText(accountText)
            .then(() => {
                alert("账号已复制到剪贴板！");
            })
            .catch(err => {
                console.error("clipboard API 复制失败", err);
                fallbackCopy(accountText);
            });
    } else {
        // 降级方案：使用传统的 textarea 复制
        fallbackCopy(accountText);
    }
}

// 传统复制方案（兼容所有浏览器）
function fallbackCopy(text) {
    const textarea = document.createElement("textarea");
    textarea.value = text;
    // 隐藏元素，避免影响页面布局
    textarea.style.position = "fixed";
    textarea.style.left = "-9999px";
    textarea.style.top = "-9999px";
    document.body.appendChild(textarea);
    textarea.select();
    try {
        document.execCommand("copy");
        alert("账号已复制到剪贴板！");
    } catch (err) {
        console.error("传统复制失败", err);
        alert("复制失败，请手动复制账号：" + text);
    } finally {
        document.body.removeChild(textarea);
    }
}

// 页面加载后执行
// window.addEventListener('DOMContentLoaded', () => {
//     const token = getToken();
//     if (token) {
//         // 显示“快速登录上次账号”按钮
//         const div = document.createElement('div');
//         div.innerHTML = `<button id="quickLogin">快速登录上次账号</button>`;
//         document.getElementById('loginForm').appendChild(div);

//         document.getElementById('quickLogin').onclick = async () => {
//             // 直接用token登录，不输入账号密码
//             const res = await fetch("/api/check_token", {
//                 method: "POST",
//                 headers: { "Content-Type": "application/json" },
//                 body: JSON.stringify({ token })
//             });
//             const data = await res.json();
//             if (data.code === 0) {
//                 loadPage('chat');
//             } else {
//                 removeToken();
//                 alert("登录已过期，请重新登录");
//             }
//         };
//     }
// });

/**
 * 页面加载完成后，统一绑定事件
 */
document.addEventListener("DOMContentLoaded", function() {
    console.log("【页面加载完成】开始绑定事件");
    // 1. 登录页【立即注册】文字 → 点击去注册
    document.querySelector("#loginPanel .switch-btn").addEventListener("click", function () {
        console.log("【DOM事件】立即注册被点击");
        goToRegister();
    });

    // 2. 注册页【返回登录】文字 → 点击去登录
    document.querySelector("#registerPanel .switch-btn").addEventListener("click", goToLogin);

    // 3. 登录按钮 → 执行登录
    document.querySelector("#loginPanel .submit-btn").addEventListener("click", doLogin);

    // 4. 注册按钮 → 执行注册
    document.querySelector("#registerPanel .submit-btn").addEventListener("click", doRegister);

    // 5. 注册成功【前往登录】
    document.querySelector("#registerSuccessPanel .submit-btn").addEventListener("click", goToLogin);

    // 6. 复制账号按钮
    document.getElementById("copyBtn").addEventListener("click", copyAccount);

    // 初始化
    changeState(AUTH_STATE.LOGIN);
});