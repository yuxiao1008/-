/*
    yx_notification NUI 脚本
    处理通知的创建、动画和生命周期管理
*/

(function () {
    'use strict';

    const container = document.getElementById('notification-container');

    // 当前活跃通知数量
    let activeCount = 0;
    let maxNotifications = 5;

    // 类型配置映射（从 Lua Config 同步）
    const typeConfig = {
        success: { icon: 'fa-solid fa-circle-check', color: '#4CAF50', label: '成功' },
        error:   { icon: 'fa-solid fa-circle-xmark', color: '#F44336', label: '错误' },
        primary: { icon: 'fa-solid fa-circle-info', color: '#2196F3', label: '信息' },
        warning: { icon: 'fa-solid fa-triangle-exclamation', color: '#FF9800', label: '警告' },
        police:  { icon: 'fa-solid fa-shield-halved', color: '#1565C0', label: '警察' },
        ambulance: { icon: 'fa-solid fa-truck-medical', color: '#E91E63', label: '急救' },
    };

    // 动画配置
    let animConfig = {
        enter: 'animate__backInLeft',
        exit: 'animate__backOutLeft',
        speed: 'animate__fast',
    };

    /**
     * 创建通知元素
     * @param {string} message - 通知消息
     * @param {string} type - 通知类型
     * @param {number} duration - 显示时长（毫秒）
     */
    function createNotification(message, type, duration) {
        // 获取类型配置，不存在则使用 primary
        const config = typeConfig[type] || typeConfig['primary'];
        duration = duration || 5000;

        // 超出最大数量时移除最早的通知
        while (activeCount >= maxNotifications) {
            const oldest = container.lastElementChild;
            if (oldest) {
                removeNotification(oldest, true);
            } else {
                break;
            }
        }

        // 创建通知 DOM
        const item = document.createElement('div');
        item.className = `notification-item animate__animated ${animConfig.enter} ${animConfig.speed}`;
        item.style.setProperty('--notify-color', config.color);

        item.innerHTML = `
            <div class="notification-icon">
                <i class="${config.icon}"></i>
            </div>
            <div class="notification-content">
                <div class="notification-title">${config.label}</div>
                <div class="notification-message">${escapeHtml(message)}</div>
            </div>
            <div class="notification-progress"></div>
        `;

        // 插入到容器顶部（视觉上最新的在底部，column-reverse）
        container.prepend(item);
        activeCount++;

        // 进场动画结束后启动进度条和自动移除
        const progressBar = item.querySelector('.notification-progress');

        item.addEventListener('animationend', function onEnter(e) {
            if (e.animationName && !e.animationName.includes('back') && !e.animationName.includes('Back')) return;
            item.removeEventListener('animationend', onEnter);

            // 移除进场动画类
            item.classList.remove(animConfig.enter, animConfig.speed);

            // 启动进度条动画
            progressBar.style.width = '100%';
            // 强制重绘
            void progressBar.offsetWidth;
            progressBar.style.transition = `width ${duration}ms linear`;
            progressBar.style.width = '0%';

            // 自动移除定时器
            item._removeTimer = setTimeout(() => {
                removeNotification(item, false);
            }, duration);
        }, { once: false });

        // 备用：如果 animationend 没触发（极端情况），600ms 后强制启动
        setTimeout(() => {
            if (item._removeTimer) return; // 已经启动了
            item.classList.remove(animConfig.enter, animConfig.speed);
            progressBar.style.width = '100%';
            void progressBar.offsetWidth;
            progressBar.style.transition = `width ${duration}ms linear`;
            progressBar.style.width = '0%';
            item._removeTimer = setTimeout(() => {
                removeNotification(item, false);
            }, duration);
        }, 600);
    }

    /**
     * 移除通知（播放出场动画后删除）
     * @param {HTMLElement} item - 通知元素
     * @param {boolean} instant - 是否立即移除（不播放动画）
     */
    function removeNotification(item, instant) {
        if (item._removing) return;
        item._removing = true;

        // 清除自动移除定时器
        if (item._removeTimer) {
            clearTimeout(item._removeTimer);
            item._removeTimer = null;
        }

        if (instant) {
            // 立即移除
            item.remove();
            activeCount = Math.max(0, activeCount - 1);
            return;
        }

        // 播放出场动画
        item.classList.add('animate__animated', animConfig.exit, animConfig.speed);

        item.addEventListener('animationend', function onExit() {
            item.removeEventListener('animationend', onExit);
            item.remove();
            activeCount = Math.max(0, activeCount - 1);
        }, { once: true });

        // 备用：动画超时后强制移除
        setTimeout(() => {
            if (item.parentNode) {
                item.remove();
                activeCount = Math.max(0, activeCount - 1);
            }
        }, 800);
    }

    /**
     * HTML 转义，防止 XSS
     */
    function escapeHtml(text) {
        const div = document.createElement('div');
        div.textContent = text;
        return div.innerHTML;
    }

    // #region agent log
    function debugLog(location, message, data, hypothesisId) {
        fetch('http://127.0.0.1:7243/ingest/5389157c-5ccb-4d1d-b87c-863cd8e3d110',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({location:location,message:message,data:data||{},hypothesisId:hypothesisId||'',timestamp:Date.now()})}).catch(()=>{});
    }
    // #endregion

    /**
     * 监听 NUI 消息
     */
    window.addEventListener('message', function (event) {
        const data = event.data;

        // #region agent log
        if (data.action === 'notify' || data.action === 'config') {
            debugLog('html/script.js:message', 'NUI message received', {action: data.action, message: data.message, type: data.type}, 'H-C');
        }
        // #endregion

        if (data.action === 'notify') {
            // #region agent log
            debugLog('html/script.js:createNotification', 'Creating notification', {message: data.message, type: data.type, duration: data.duration, containerExists: !!container}, 'H-C');
            // #endregion
            createNotification(data.message, data.type, data.duration);
        }

        if (data.action === 'config') {
            // 从 Lua 同步配置
            if (data.maxNotifications) {
                maxNotifications = data.maxNotifications;
            }
            if (data.animation) {
                animConfig.enter = data.animation.enter || animConfig.enter;
                animConfig.exit = data.animation.exit || animConfig.exit;
                animConfig.speed = data.animation.speed || animConfig.speed;
            }
            if (data.types) {
                for (const [key, val] of Object.entries(data.types)) {
                    typeConfig[key] = val;
                }
            }
        }
    });
})();

