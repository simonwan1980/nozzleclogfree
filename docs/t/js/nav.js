document.addEventListener('DOMContentLoaded', function() {
    const navToggle = document.querySelector('.nav-toggle');
    const navSidebar = document.querySelector('.nav-sidebar');
    let isNavOpen = true;

    function toggleNav() {
        isNavOpen = !isNavOpen;
        navSidebar.classList.toggle('collapsed');
        document.body.classList.toggle('nav-collapsed');
        navToggle.innerHTML = isNavOpen ? '≡' : '≡';
    }

    navToggle.addEventListener('click', toggleNav);

    // 获取所有页面区域和导航链接
    const sections = document.querySelectorAll('[id^="page"]');
    const navLinks = document.querySelectorAll('.nav-list a');
    let isScrolling = false;
    let currentClickedLink = null;

    // 更新活动链接
    function updateActiveLink(id) {
        navLinks.forEach(link => link.classList.remove('active'));
        const activeLink = document.querySelector(`.nav-list a[href="#${id}"]`);
        if (activeLink) {
            activeLink.classList.add('active');
        }
    }

    // 创建Intersection Observer来检测页面区域的可见性
    const observer = new IntersectionObserver((entries) => {
        if (isScrolling) return; // 如果正在滚动，不处理交叉点

        // 找出最大交叉比例的区域
        let maxEntry = null;
        entries.forEach(entry => {
            if (!maxEntry || entry.intersectionRatio > maxEntry.intersectionRatio) {
                maxEntry = entry;
            }
        });

        if (maxEntry && maxEntry.intersectionRatio > 0.5) {
            updateActiveLink(maxEntry.target.id);
        }
    }, {
        threshold: [0, 0.25, 0.5, 0.75, 1], // 使用多个阈值来获得更精确的交叉比例
        rootMargin: '-10% 0px -10% 0px' // 减少边距，使判断更精确
    });

    // 观察所有页面区域
    sections.forEach(section => observer.observe(section));

    // 处理导航点击
    navLinks.forEach(link => {
        link.addEventListener('click', function(e) {
            e.preventDefault();
            const targetId = this.getAttribute('href').substring(1);
            const targetElement = document.getElementById(targetId);

            if (targetElement) {
                isScrolling = true; // 开始滚动
                currentClickedLink = this;
                updateActiveLink(targetId); // 立即更新活动链接

                targetElement.scrollIntoView({ behavior: 'smooth' });

                // 等待滚动结束
                setTimeout(() => {
                    isScrolling = false;
                }, 1000); // 给予足够的时间让滚动完成
            }
        });
    });
});
