/**
 * 热浪扭曲效果 JavaScript
 * 使用方法: 
 * 1. 引入 heatwave-effect.css 和 heatwave-effect.js
 * 2. 调用 applyHeatwaveEffect(selector) 函数，传入图片的选择器
 */

/**
 * 将热浪效果应用到指定的图片元素上
 * @param {string} selector - CSS选择器，用于选择要应用效果的图片元素
 * @param {Object} options - 可选配置项
 * @param {boolean} options.useTurbulence - 是否使用SVG湍流效果，默认为true
 * @param {number} options.layers - 要使用的层数，默认为20，最大为20
 */
function applyHeatwaveEffect(selector, options = {}) {
    // 默认配置
    const defaults = {
        useTurbulence: true,
        layers: 20
    };
    
    // 合并配置
    const settings = Object.assign({}, defaults, options);
    
    // 限制层数在1-20之间
    settings.layers = Math.min(20, Math.max(1, settings.layers));
    
    // 获取所有匹配的图片元素
    const images = document.querySelectorAll(selector);
    
    // 为每个图片应用热浪效果
    images.forEach((img) => {
        // 1. 创建容器
        const container = document.createElement('div');
        container.className = 'heatwave-container';
        
        // 2. 获取图片的原始属性
        const imgSrc = img.src;
        const imgAlt = img.alt || '';
        const imgWidth = img.width;
        const imgHeight = img.height;
        const imgClasses = img.className;
        
        // 3. 创建新的图片元素
        const newImg = document.createElement('img');
        newImg.src = imgSrc;
        newImg.alt = imgAlt;
        newImg.className = `heatwave-image ${imgClasses}`;
        
        // 4. 将图片添加到容器
        container.appendChild(newImg);
        
        // 5. 创建扭曲层
        for (let i = 1; i <= settings.layers; i++) {
            const layer = document.createElement('div');
            layer.className = `distortion-layer layer${i}`;
            layer.style.backgroundImage = `url(${imgSrc})`;
            container.appendChild(layer);
        }
        
        // 6. 如果启用湍流效果，添加SVG滤镜
        if (settings.useTurbulence) {
            // 添加SVG滤镜定义
            const svgFilters = document.createElement('svg');
            svgFilters.className = 'svg-filters';
            svgFilters.innerHTML = `
                <defs>
                    <filter id="turbulence-${generateUniqueId()}" x="0%" y="0%" width="100%" height="100%">
                        <feTurbulence baseFrequency="0.02 0.1" numOctaves="3" result="noise">
                            <animate attributeName="baseFrequency" 
                                     values="0.02 0.1;0.03 0.12;0.02 0.1" 
                                     dur="4s" 
                                     repeatCount="indefinite"/>
                        </feTurbulence>
                        <feDisplacementMap in="SourceGraphic" in2="noise" scale="5">
                            <animate attributeName="scale" 
                                     values="3;8;3" 
                                     dur="3s" 
                                     repeatCount="indefinite"/>
                        </feDisplacementMap>
                    </filter>
                </defs>
            `;
            container.appendChild(svgFilters);
            
            // 添加湍流覆盖层
            const turbulenceOverlay = document.createElement('div');
            turbulenceOverlay.className = 'turbulence-overlay';
            // 使用唯一ID引用滤镜
            const filterId = svgFilters.querySelector('filter').id;
            turbulenceOverlay.style.filter = `url(#${filterId})`;
            container.appendChild(turbulenceOverlay);
        }
        
        // 7. 替换原始图片
        img.parentNode.replaceChild(container, img);
    });
}

/**
 * 生成唯一ID，用于SVG滤镜
 * @returns {string} 唯一ID
 */
function generateUniqueId() {
    return 'heatwave-' + Math.random().toString(36).substr(2, 9);
}

// 如果在浏览器环境中，将函数暴露到全局作用域
if (typeof window !== 'undefined') {
    window.applyHeatwaveEffect = applyHeatwaveEffect;
}
