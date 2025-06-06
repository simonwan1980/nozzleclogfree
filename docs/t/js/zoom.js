document.addEventListener('DOMContentLoaded', function() {
    const imageStates = new Map();
    const TARGET_HEIGHT = 800; // 目标高度

    // 初始化图片状态
    function initializeImageState(image) {
        const rect = image.getBoundingClientRect();
        const currentTransform = window.getComputedStyle(image).transform;
        imageStates.set(image, {
            initialHeight: rect.height,
            baseTransformValue: currentTransform === 'none' ? '' : currentTransform
        });
    }

    // 处理图片悬停
    const handleImageHover = function(event) {
        const image = event.target;
        const state = imageStates.get(image);
        if (!state) return;

        // 获取父容器尺寸
        const container = image.closest('.horizontal-center');
        if (!container) return;

        const containerRect = container.getBoundingClientRect();
        const imageRect = image.getBoundingClientRect();

        // 计算缩放比例
        const scaleFactor = TARGET_HEIGHT / state.initialHeight;

        // 计算垂直偏移，使图片在容器中居中
        const finalHeight = TARGET_HEIGHT;
        const currentTop = imageRect.top - containerRect.top;
        const targetTop = (containerRect.height - finalHeight) / 2;
        const translateYValue = targetTop - currentTop;

        const newTransform = `translateY(${translateYValue.toFixed(2)}px) translateZ(0px) scale(${scaleFactor.toFixed(4)})`;
        image.style.transform = newTransform;
    };

    // 处理图片离开
    function handleImageLeave(event) {
        const image = event.target;
        const state = imageStates.get(image);
        if (state) {
            image.style.transform = state.baseTransformValue;
        }
    }

    // 初始化所有zoom-image
    function initializeZoomImages() {
        const zoomImages = document.querySelectorAll('.zoom-image');
        zoomImages.forEach(image => {
            initializeImageState(image);
            image.addEventListener('mouseenter', handleImageHover);
            image.addEventListener('mouseleave', handleImageLeave);
        });
    }

    initializeZoomImages();
});