// app.js

const TOKEN_KEY = "roomtalk_token";

/**
 * 加载页面：拼接html、动态加载对应css
 * @param {string} page 页面名称 login / chat
 */
async function loadPage(page) {
    
    window.location.href = `/pages/${page}.html`;
}
/**
 * 获取本地token
 */
function getToken() {
    return localStorage.getItem(TOKEN_KEY); // 不存在 = null
}

/**
 * 设置token
 */
function setToken(token) {
    localStorage.setItem(TOKEN_KEY, token);
}

/**
 * 删除token（退出登录）
 */
function removeToken() {
    localStorage.removeItem(TOKEN_KEY);
}

/**
 * 初始化路由
 * 重点：永远先进登录页，不自动跳转！
 */
window.onload = function () {
    // 永远先加载登录页！！！
    loadPage('login');

    // 在登录页里，再判断是否有token
    // 这样用户永远可以选择：登新号 或 快速登旧号
};