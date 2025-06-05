// 全局变量记录鼠标是否在导航区域

let isMouseOverNav = false;

document.addEventListener('DOMContentLoaded', function() {
    // 初始化侧边栏切换功能
    initSidebar();
    
    // 初始化导航区域鼠标事件
    const sidebar = document.querySelector('.sidebar-content');
    if (sidebar) {
        sidebar.addEventListener('mouseenter', function() {
            isMouseOverNav = true;
        });
        
        sidebar.addEventListener('mouseleave', function() {
            isMouseOverNav = false;
        });

        // 防止滚动传播
        sidebar.addEventListener('wheel', function(event) {
            const scrollTop = sidebar.scrollTop;
            const scrollHeight = sidebar.scrollHeight;
            const height = sidebar.clientHeight;

            // 如果已经到达顶部或底部，阻止滚动传播
            if ((scrollTop <= 0 && event.deltaY < 0) || 
                (scrollTop + height >= scrollHeight && event.deltaY > 0)) {
                event.preventDefault();
            }
        }, { passive: false });
    }
    
    // 初始化当前页面的活动菜单项
    window.addEventListener('hashchange', function() {
        const hash = window.location.hash;
        if (hash) {
            const id = hash.substring(1);
            updateActiveMenuItem(id);
        }
    });

    // 添加滚动事件监听
    let scrollTimeout;
    window.addEventListener('scroll', function() {
        // 使用防抖来优化性能
        if (scrollTimeout) {
            clearTimeout(scrollTimeout);
        }
        scrollTimeout = setTimeout(function() {
            updateActiveMenuItemOnScroll();
        }, 100);
    });
    
    // 内容结构已经在 content-structure.js 中开始加载
    // 这里不需要再调用 loadContentStructure()
});

// 监听内容结构加载完成事件
document.addEventListener('contentStructureLoaded', function(event) {
    // 获取加载完成的内容结构
    const contentStructure = event.detail.contentStructure;
    
    // 生成导航菜单
    generateNavigationMenu(contentStructure);
    
    // 初始化当前页面的活动菜单项
    initActiveMenuItem();
    
    // 加载所有内容
    loadAllContent(contentStructure);
});

// 侧边栏切换功能
function initSidebar() {
    const sidebar = document.getElementById('sidebar');
    const mainContent = document.getElementById('mainContent');
    const sidebarToggle = document.getElementById('sidebarToggle');
    
    sidebarToggle.addEventListener('click', function() {
        sidebar.classList.toggle('hidden');
        mainContent.classList.toggle('expanded');
    });

    // Ensure sidebar is expanded by default
    //sidebar.classList.remove('hidden');
    //mainContent.classList.add('expanded');
}

// loadContentStructure 函数已移至 content-structure.js 文件中

// 生成导航菜单
function generateNavigationMenu(structure) {
    const menuContainer = document.getElementById('navigationMenu');
    menuContainer.innerHTML = ''; // 清空现有内容
    
    // 按照level分组内容
    const menuStructure = buildMenuStructure(structure);
    
    // 创建菜单
    const ul = document.createElement('ul');
    let navItemCounter = 1; // Initialize counter for navigation items
    
    // 递归创建菜单项函数
    function createMenuItems(items, parentUl) {
        items.forEach(item => {
            const li = document.createElement('li');
            const a = document.createElement('a');
            a.href = `#${item.id}`;
            a.textContent = `${navItemCounter}. ${item.title}`; // Add number prefix
            navItemCounter++; // Increment for the next item
            li.appendChild(a);
            
            // 如果有子项，添加子菜单
            if (item.children && item.children.length > 0) {
                li.classList.add('has-submenu');
                li.classList.add('open'); // Expand submenu by default
                
                // 创建展开/收起按钮
                const toggleBtn = document.createElement('span');
                toggleBtn.className = 'submenu-toggle';
                toggleBtn.innerHTML = '-'; // Set to expanded state by default
                li.appendChild(toggleBtn);
                
                // 为展开/收起按钮添加事件
                toggleBtn.addEventListener('click', function(e) {
                    e.stopPropagation(); // 阻止事件冒泡
                    li.classList.toggle('open');
                    this.innerHTML = li.classList.contains('open') ? '-' : '+';
                });
                
                // 创建子菜单
                const subUl = document.createElement('ul');
                
                // 递归创建子菜单项
                createMenuItems(item.children, subUl);
                
                li.appendChild(subUl);
            }
            
            // 链接点击滚动到内容
            a.addEventListener('click', function(e) {
                e.preventDefault();
                scrollToContent(item.id);
                updateActiveMenuItem(item.id);
            });
            
            parentUl.appendChild(li);
        });
    }
    
    // 初始调用递归函数
    createMenuItems(menuStructure, ul);
    
    menuContainer.appendChild(ul);
}

// 根据内容结构构建菜单结构
function buildMenuStructure(structure) {
    // 按照数组顺序和level构建菜单结构
    const menuItems = [];
    
    // 使用对象来跟踪每个级别的当前父项
    const parentStack = {};
    
    // 遍历所有内容项
    for (let i = 0; i < structure.length; i++) {
        const item = structure[i];
        const level = item.level;
        
        // 创建菜单项对象，并添加children数组
        const menuItem = {
            ...item,
            children: []
        };
        
        if (level === 1) {
            // 如果是一级菜单，直接添加到菜单项数组
            menuItems.push(menuItem);
            parentStack[1] = menuItem;
        } else {
            // 如果是更高级的菜单，添加到上一级父项的children数组
            const parentLevel = level - 1;
            const parent = parentStack[parentLevel];
            
            if (parent) {
                parent.children.push(menuItem);
                parentStack[level] = menuItem;
            }
        }
    }
    
    return menuItems;
}

// 加载所有内容
function loadAllContent(structure) {
    const mainContent = document.getElementById('mainContent');
    
    // 清空主内容区域
    mainContent.innerHTML = '';
    
    // 保持原始数组顺序加载内容
    structure.forEach(item => {
        // 创建内容区域容器
        const section = document.createElement('section');
        section.id = item.id;
        section.className = 'content-section';
        section.setAttribute('data-level', item.level);
        mainContent.appendChild(section); // 先添加到DOM中
        
        // 获取内容路径的目录部分
        const basePath = item.path.substring(0, item.path.lastIndexOf('/') + 1);
        
        // 使用fetch获取内容，然后处理相对路径
        fetch(item.path)
            .then(response => response.text())
            .then(html => {
                // 处理相对路径，将所有相对路径转换为基于原始文件路径的相对路径
                
                // 创建一个基本的HTML解析器
                const parser = new DOMParser();
                const doc = parser.parseFromString(html, 'text/html');
                
                // 处理所有CSS链接
                const cssLinks = doc.querySelectorAll('link[rel="stylesheet"]');
                cssLinks.forEach(link => {
                    const href = link.getAttribute('href');
                    if (href && !href.startsWith('http://') && !href.startsWith('https://') && !href.startsWith('/')) {
                        link.setAttribute('href', `${basePath}${href}`);
                    }
                });
                
                // 处理所有图片
                const images = doc.querySelectorAll('img');
                images.forEach(img => {
                    const src = img.getAttribute('src');
                    if (src && !src.startsWith('http://') && !src.startsWith('https://') && !src.startsWith('/')) {
                        img.setAttribute('src', `${basePath}${src}`);
                    }
                });
                
                // 处理所有iframe
                const iframes = doc.querySelectorAll('iframe');
                iframes.forEach(iframe => {
                    const src = iframe.getAttribute('src');
                    if (src && !src.startsWith('http://') && !src.startsWith('https://') && !src.startsWith('/')) {
                        iframe.setAttribute('src', `${basePath}${src}`);
                    }
                });
                
                // 将处理后的HTML转回字符串
                html = doc.documentElement.outerHTML;
                
                // 创建iframe并设置srcdoc
                const iframe = document.createElement('iframe');
                iframe.srcdoc = html;
                iframe.style.width = '100%';
                iframe.style.height = '20px'; // 设置适当的高度
                iframe.style.border = 'none';
                iframe.style.overflow = 'hidden';
                iframe.onload = function() {
                    // 尝试自适应iframe高度
                    try {
                        const iframeBody = iframe.contentWindow.document.body;
                        const iframeHeight = iframeBody.scrollHeight;
                        iframe.style.height = (iframeHeight + 20) + 'px'; // 添加20px的缓冲
                    } catch(e) {
                        console.warn('Cannot adjust iframe height:', e);
                    }
                };
                
                section.appendChild(iframe);
            })
            .catch(error => {
                console.error(`加载内容失败: ${item.path}`, error);
                section.innerHTML = `<h2>${item.title}</h2><p>内容加载失败: ${error.message}</p>`;
            });
    });
}

// 获取内容 - 不再需要这个函数，因为我们现在使用iframe
function fetchContent(path) {
    // 保留这个函数以保持兼容性，但实际上不再使用
    return new Promise((resolve) => {
        resolve('');
    });
}

// 滚动到指定内容
function scrollToContent(id) {
    const element = document.getElementById(id);
    if (element) {
        element.scrollIntoView({ behavior: 'smooth' });
        // Update URL hash without triggering scroll
        if (updateHash) {
            history.pushState(null, '', `#${id}`);
        }
    }
}

// 更新当前活动的导航菜单项
function updateActiveMenuItem(id, updateHash = true) {
    // Remove active class from all menu items
    const allMenuItems = document.querySelectorAll('#navigationMenu a');
    allMenuItems.forEach(item => item.classList.remove('active'));
    
    // Add active class to current menu item
    const currentItem = document.querySelector(`#navigationMenu a[href="#${id}"]`);
    if (currentItem) {
        currentItem.classList.add('active');
        
        // Expand parent menus if item is in a submenu
        let parent = currentItem.parentElement;
        while (parent && parent.classList.contains('has-submenu')) {
            parent.classList.add('open');
            const toggle = parent.querySelector('.submenu-toggle');
            if (toggle) toggle.innerHTML = '-';
            parent = parent.parentElement ? parent.parentElement.closest('.has-submenu') : null;
        }

        // 将高亮项滚动到导航栏的中间
        const sidebar = document.querySelector('.sidebar-content');
        if (sidebar && !isMouseOverNav) { // 只在鼠标不在导航区域时滚动
            // 等待一下DOM更新（展开的子菜单），再计算滚动位置
            setTimeout(() => {
                // 再次检查鼠标状态，因为可能在这100ms内发生变化
                if (!isMouseOverNav) {
                    const sidebarRect = sidebar.getBoundingClientRect();
                    const itemRect = currentItem.getBoundingClientRect();
                    
                    // 计算目标滚动位置：将当前项移动到导航栏的中间
                    const targetScroll = sidebar.scrollTop + 
                        (itemRect.top - sidebarRect.top) - 
                        (sidebarRect.height / 2) + 
                        (itemRect.height / 2);
                    
                    // 使用平滑滚动
                    sidebar.scrollTo({
                        top: targetScroll,
                        behavior: 'smooth'
                    });
                }
            }, 100);
        }
    }
}

// 从URL hash初始化活动菜单项
function initActiveMenuItem() {
    const hash = window.location.hash;
    if (hash) {
        const id = hash.substring(1); // Remove the # symbol
        updateActiveMenuItem(id);
    } else {
        // 如果没有hash，根据滚动位置初始化
        updateActiveMenuItemOnScroll();
    }
}

// 根据页面滚动位置更新活动菜单项
function updateActiveMenuItemOnScroll() {
    // 获取所有内容区域
    const contentSections = Array.from(document.querySelectorAll('[id]')).filter(el => {
        // 确保元素有对应的导航项
        return document.querySelector(`#navigationMenu a[href="#${el.id}"]`);
    });

    if (contentSections.length === 0) return;

    // 找到当前视口中最靠近顶部的内容区域
    let currentSection = contentSections[0];
    let minDistance = Infinity;

    contentSections.forEach(section => {
        const rect = section.getBoundingClientRect();
        // 计算元素顶部到视口顶部的距离
        const distance = Math.abs(rect.top);
        
        // 如果元素在视口内或刚好在视口上方，并且距离更近
        if (distance < minDistance) {
            minDistance = distance;
            currentSection = section;
        }
    });

    // 更新导航菜单高亮，但不更新URL hash
    updateActiveMenuItem(currentSection.id, false);
}

// 移除全局点击事件处理器，因为我们现在使用单独的展开/收起按钮
