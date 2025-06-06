function createFlash() {
    const flash = document.getElementById('flashOverlay');
    
    if (!flash) return;
    
    // 移除所有可能的闪烁类
    flash.classList.remove('flash-1', 'flash-2', 'flash-3', 'flash-4');
    
    // 随机选择闪烁效果
    const flashTypes = ['flash-1', 'flash-2', 'flash-3', 'flash-4'];
    const randomFlash = flashTypes[Math.floor(Math.random() * flashTypes.length)];
    
    // 强制重绘
    flash.offsetHeight;
    
    // 添加随机闪烁动画
    flash.classList.add(randomFlash);
    
    // 根据不同的动画持续时间设置移除类的时间
    const durations = {
        'flash-1': 600,
        'flash-2': 500,
        'flash-3': 700,
        'flash-4': 400
    };
    
    // 动画结束后移除类
    setTimeout(() => {
        flash.classList.remove(randomFlash);
    }, durations[randomFlash]);
}

function startAutoFlash() {
    // 立即执行一次
    createFlash();
    
    // 设置随机间隔的自动闪烁
    function scheduleNext() {
        // 生成更随机的间隔：2-8秒，但偶尔会有更短的间隔（1-2秒）
        const shortInterval = Math.random() < 0.2; // 20%的概率是短间隔
        const delay = shortInterval 
            ? Math.random() * 1000 + 1000  // 1-2秒
            : Math.random() * 2000 + 2000; // 2-4秒
        setTimeout(() => {
            createFlash();
            scheduleNext(); // 递归调用以继续循环
        }, delay);
    }
    
    scheduleNext();
}

function stopAutoFlash() {
    if (flashTimer) {
        console.log('%c[Flash Effect] Stopping auto flash', 'color: #FFA500');
        clearTimeout(flashTimer);
        flashTimer = null;
        flashCount = 0;
    }
}

// 检查CSS样式是否正确加载
function checkFlashStyles() {
    // 检查样式是否加载，但不输出日志
    const styleSheets = document.styleSheets;
    let flashStylesFound = 0;
    let flashKeyframesFound = 0;

    for (let sheet of styleSheets) {
        try {
            const rules = sheet.cssRules || sheet.rules;
            for (let rule of rules) {
                if (rule instanceof CSSStyleRule) {
                    for (let i = 1; i <= 4; i++) {
                        if (rule.selectorText === `.flash-${i}`) {
                            flashStylesFound++;
                        }
                    }
                }
                if (rule instanceof CSSKeyframesRule) {
                    for (let i = 1; i <= 4; i++) {
                        if (rule.name === `flash-${i}`) {
                            flashKeyframesFound++;
                        }
                    }
                }
            }
        } catch (e) {}
    }

    return flashStylesFound > 0 && flashKeyframesFound > 0;
}

// 页面加载完成后开始自动闪烁
document.addEventListener('DOMContentLoaded', () => {
    if (checkFlashStyles() && document.getElementById('flashOverlay')) {
        setTimeout(startAutoFlash, 1000);
    }
});

// 页面隐藏或卸载时停止闪烁
window.addEventListener('pagehide', stopAutoFlash);

// 导出调试函数
window.debugFlash = {
    createFlash,
    startAutoFlash,
    stopAutoFlash,
    checkFlashStyles
};