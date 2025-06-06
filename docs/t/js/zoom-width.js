document.addEventListener('DOMContentLoaded', function() {
    const TARGET_SCALE = 2; // 放大2倍

    // 处理图片悬停
    const handleImageHover = function(event) {
        const image = event.target;
        image.style.transform = `scale(${TARGET_SCALE})`;
    };

    // 处理图片离开
    function handleImageLeave(event) {
        const image = event.target;
        image.style.transform = '';
    }

    // 初始化所有zoom-image-width
    function initializeZoomImages() {
        const zoomImages = document.querySelectorAll('.zoom-image-width');
        zoomImages.forEach(image => {
            image.addEventListener('mouseenter', handleImageHover);
            image.addEventListener('mouseleave', handleImageLeave);
        });
    }

    initializeZoomImages();

    // 监听窗口大小变化
    window.addEventListener('resize', initializeZoomImages);
});
