document.addEventListener('DOMContentLoaded', () => {
    // Scroll animations using Intersection Observer
    
    // Header Scroll Effect - Hide on first page, show on scroll
    const header = document.querySelector('header');
    
    // Initial check
    if (window.scrollY > window.innerHeight) {
        header.classList.add('header-visible', 'scrolled');
    }

    window.addEventListener('scroll', () => {
        // Show header only after scrolling past the Hero section (100vh)
        if (window.scrollY > window.innerHeight - 100) { // slightly before end of hero
            header.classList.add('header-visible', 'scrolled');
        } else {
            header.classList.remove('header-visible', 'scrolled');
        }
    });

    // Initiate intro animation
    const hero = document.querySelector('.hero');
    if (hero) {
        setTimeout(() => hero.classList.add('fade-in-active'), 100);
    }

    const observerOptions = {
        threshold: 0.1
    };

    const observer = new IntersectionObserver((entries) => {
        entries.forEach(entry => {
            if (entry.isIntersecting) {
                entry.target.classList.add('fade-in-active'); // We'll add this class in CSS if needed or just use the existing animation
            }
        });
    }, observerOptions);

    document.querySelectorAll('.fade-in').forEach(el => observer.observe(el));

    // --- Internationalization (i18n) ---
    const translations = {
        'zh': {
            'nav_home': '首页',
            'nav_features': '功能',
            'nav_download': '下载',
            'nav_cta': '立即下载',
            'badge_new': '🎉 doNow v1.0 现已发布',
            'hero_center_1': '捕捉灵感',
            'hero_center_2': '即刻行动',
            'hero_side_left': '以声为引<br>捕捉灵感',
            'hero_side_right': '化繁为简<br>即刻成行',
            'hero_desc': '一款融合 AI 实时语音对话的智能效率工具。<br>开口即创建任务，对话即获得陪伴，让每一个想法都能落地生根。',
            'feature_poker_title': '消灭拖延，<br>从最小一步开始',
            'feature_poker_desc': '面对大任务无从下手？AI 帮你自动拆解为最小子任务。<br>配合灵动岛实时计时督促，让执行力依次击破。',
            'screen_poker_1': 'AI 任务拆解',
            'screen_poker_2': '专注计时中',
            'screen_poker_3': '灵动岛实时反馈',
            'feature_decision_title': '告别纠结，<br>把命运交给硬币',
            'feature_decision_desc': '中午吃什么？周末去哪玩？<br>治愈选择困难症，在随机中遇见惊喜。',
            'screen_decision': '决策 UI界面',
            'feature_focus_title': '屏幕一横，即刻专注',
            'feature_focus_desc': '手机横放自动进入沉浸模式。白噪音与番茄钟相伴，<br>在张弛有度中，找回心流体验。',
            'screen_focus': '横屏专注模式',
            'carousel_t1_title': '金句启发',
            'carousel_t1_p1': '有时候，我们需要的不是安慰，而是一针见血的真相。',
            'carousel_t1_p2': '一口气倾诉所有烦心事，AI 会从你的话语中提炼核心洞察，用一句振聋发聩的金句，帮你找到突破口。',
            'screen_inspiration': '灵感 UI',
            'carousel_t2_title': '贴心陪伴',
            'carousel_t2_p1': '有时候，我们只是想找个人聊聊，不需要建议，只需要倾听。',
            'carousel_t2_p2': '选择陪伴模式，AI 会像老友一样耐心倾听你的碎碎念，每一句回应都充满理解与温度，让你感到被真正看见。',
            'screen_comfort': '陪伴 UI',
            'growth_title': '每一次努力，都看得见',
            'growth_subtitle': '不只是完成任务，更是见证自己的成长轨迹。',
            'growth_item_1_title': '时间线系统',
            'growth_item_1_desc': '每一天做的事情都被完整记录。<br>无论是完成的任务、专注的时长，还是倾诉的心声，都成为你人生故事的一部分。',
            'growth_item_2_title': '智能总结',
            'growth_item_2_desc': '每晚，AI 会为你复盘这一天。<br>哪些目标达成了？哪些可以改进？用数据和洞察，帮你看清自己的节奏。',
            'growth_item_3_title': '经验与成就',
            'growth_item_3_desc': '完成任务获得经验，积累等级解锁勋章。<br>把自律变成一场游戏，让坚持本身成为奖励。',
            'download_slogan': '"说出来，就是行动的开始"',
            'download_desc_1': 'doNow 相信，每一个闪过脑海的念头都值得被珍视。通过 AI 语音交互，我们将"想到"与"做到"之间的距离，缩短为一次开口。',
            'download_desc_2': '免费下载，即刻体验。让 doNow 成为你大脑的最佳搭档。',
            'footer_desc': '让每一个想法落地生根。你的智能效率助手，随时待命。',
            'footer_h_company': '公司',
            'footer_l_about': '关于我们',
            'footer_l_blog': '博客',
            'footer_l_jobs': '工作机会',
            'footer_h_legal': '法律',
            'footer_l_privacy': '隐私政策',
            'footer_l_terms': '用户协议',
            'footer_l_cookie': 'Cookie 设置',
            'footer_design': 'Designed with <span style="color: #e25555;">♥</span> for productivity'
        },
        'en': {
            'nav_home': 'Home',
            'nav_features': 'Features',
            'nav_download': 'Download',
            'nav_cta': 'Get App',
            'badge_new': '🎉 doNow v1.0 is Available',
            'hero_center_1': 'Capture Ideas',
            'hero_center_2': 'Action Now',
            'hero_side_left': 'Voice Guided<br>Capture Ideas',
            'hero_side_right': 'Simplify All<br>Action Now',
            'hero_desc': 'An intelligent productivity tool fused with AI voice interaction.<br>Speak to create tasks, talk to find companionship. Let every idea take root.',
            'feature_poker_title': 'Crush Procrastination,<br>Start Small',
            'feature_poker_desc': 'Overwhelmed by big tasks? AI breaks them down into micro-steps.<br>Combined with Live Activities for real-time tracking, execute with ease.',
            'screen_poker_1': 'AI Breakdown',
            'screen_poker_2': 'Focus Timer',
            'screen_poker_3': 'Live Activity',
            'feature_decision_title': 'Stop Dithering,<br>Flip a Coin',
            'feature_decision_desc': 'Lunch? Weekend plans? <br>Cure indecision and find surprises in randomness.',
            'screen_decision': 'Decision UI',
            'feature_focus_title': 'Turn Horizontal,<br>Enter Flow',
            'feature_focus_desc': 'Rotate your phone for instant immersive mode. <br>White noise and Pomodoro timer help you find your flow.',
            'screen_focus': 'Landscape Mode',
            'carousel_t1_title': 'Sharp Insights',
            'carousel_t1_p1': 'Sometimes, you need truth, not just comfort.',
            'carousel_t1_p2': 'Pour out your thoughts. AI distills the core insight, offering a profound quote to help you break through.',
            'screen_inspiration': 'Inspiration UI',
            'carousel_t2_title': 'Warm Companion',
            'carousel_t2_p1': 'Sometimes, you just need a listener.',
            'carousel_t2_p2': 'In Companion Mode, AI listens like an old friend. Every response is warm and understanding, making you feel truly seen.',
            'screen_comfort': 'Comfort UI',
            'growth_title': 'Visualized Growth',
            'growth_subtitle': 'Not just tasks, but a trajectory of your growth.',
            'growth_item_1_title': 'Timeline Journal',
            'growth_item_1_desc': 'Every action is recorded.<br>Completed tasks, focus sessions, and vented thoughts become part of your life story.',
            'growth_item_2_title': 'Smart Review',
            'growth_item_2_desc': 'Every night, AI reviews your day.<br>What did you achieve? Where to improve? Understand your rhythm with data.',
            'growth_item_3_title': 'Gamified XP',
            'growth_item_3_desc': 'Gain XP for tasks, unlock badges.<br>Turn discipline into a game, making persistence its own reward.',
            'download_slogan': '"Speaking is the Start of Action"',
            'download_desc_1': 'doNow believes every fleeting thought is precious. We shorten the distance between "thinking" and "doing" to just one sentence.',
            'download_desc_2': 'Download for free. Make doNow your brain\'s best partner.',
            'footer_desc': 'Let every idea take root. Your intelligent productivity assistant.',
            'footer_h_company': 'Company',
            'footer_l_about': 'About Us',
            'footer_l_blog': 'Blog',
            'footer_l_jobs': 'Careers',
            'footer_h_legal': 'Legal',
            'footer_l_privacy': 'Privacy Policy',
            'footer_l_terms': 'Terms of Use',
            'footer_l_cookie': 'Cookie Settings',
            'footer_design': 'Designed with <span style="color: #e25555;">♥</span> for productivity'
        }
    };

    let currentLang = 'zh';
    const langToggle = document.getElementById('lang-toggle');

    if (langToggle) {
        langToggle.addEventListener('click', (e) => {
            e.preventDefault();
            currentLang = currentLang === 'zh' ? 'en' : 'zh';
            langToggle.textContent = currentLang === 'zh' ? 'EN' : '中';
            
            // Update Text
            document.querySelectorAll('[data-i18n]').forEach(el => {
                const key = el.getAttribute('data-i18n');
                if (translations[currentLang][key]) {
                    // Use innerHTML for ALL fields to support <br> tags and rich text
                    el.innerHTML = translations[currentLang][key];
                }
            });

            // Update Images
            document.querySelectorAll('[data-img-key]').forEach(img => {
                const key = img.getAttribute('data-img-key');
                // Construct new path: assets/key_lang.png
                // e.g., assets/poker-timer-ui_zh.png or assets/poker-timer-ui_en.png
                img.src = `assets/${key}_${currentLang}.png`;
            });

            // Update Videos
            document.querySelectorAll('[data-video-key]').forEach(video => {
                const key = video.getAttribute('data-video-key');
                video.src = `assets/${key}_${currentLang}.mp4`;
                video.load(); // Ensure reload
                video.play().catch(e => console.log('Autoplay prevented:', e));
            });
        });
    }


    // Hero Split Animation - Synchronized with Video Loop
    const heroVideo = document.getElementById('heroVideo');
    const heroEl = document.querySelector('.hero');
    
    if (heroVideo && heroEl) {
        // Use timeupdate for precise synchronization with video loop
        heroVideo.addEventListener('timeupdate', () => {
            const currentTime = heroVideo.currentTime;
            
            // At start of video (loop), show center titles
            // Reset slightly before 0 to handle loop
            if (currentTime < 2.5) {
                if (heroEl.classList.contains('hero-split')) {
                    heroEl.classList.remove('hero-split');
                }
            } 
            // After 2.5 seconds, trigger split animation (fade center out, side in)
            else if (currentTime >= 2.5) {
                if (!heroEl.classList.contains('hero-split')) {
                    heroEl.classList.add('hero-split');
                }
            }
        });

        // Ensure state is reset when video loops (seeks to 0)
        heroVideo.addEventListener('seeked', () => {
            if (heroVideo.currentTime < 0.5) {
                heroEl.classList.remove('hero-split');
            }
        });
    } else {
        // Fallback if no video: manual loop using interval
         setInterval(() => {
            heroEl.classList.remove('hero-split');
            setTimeout(() => {
                heroEl.classList.add('hero-split');
            }, 3000);
        }, 8000); // 8 second total loop cycle
        
        // Initial trigger
        setTimeout(() => {
            document.querySelector('.hero').classList.add('hero-split');
        }, 3000);
    }



    // Feature Card Spotlight Effect
    document.querySelectorAll('.feature-card').forEach(card => {
        card.addEventListener('mousemove', e => {
            const rect = card.getBoundingClientRect();
            const x = e.clientX - rect.left;
            const y = e.clientY - rect.top;
            
            card.style.setProperty('--mouse-x', `${x}px`);
            card.style.setProperty('--mouse-y', `${y}px`);
        });
    });


    // --- Scroll Snap Carousel - Dot Indicator Logic ---
    const snapCarousel = document.querySelector('.snap-carousel');
    const dot1 = document.getElementById('dot-1');
    const dot2 = document.getElementById('dot-2');

    if (snapCarousel && dot1 && dot2) {
        snapCarousel.addEventListener('scroll', () => {
            const scrollLeft = snapCarousel.scrollLeft;
            const frameWidth = snapCarousel.offsetWidth;
            
            // Determine which frame is active based on scroll position
            if (scrollLeft < frameWidth / 2) {
                dot1.classList.add('active');
                dot2.classList.remove('active');
            } else {
                dot1.classList.remove('active');
                dot2.classList.add('active');
            }
        });
        
        // Make dots clickable
        dot1.addEventListener('click', () => {
            snapCarousel.scrollTo({ left: 0, behavior: 'smooth' });
        });
        dot2.addEventListener('click', () => {
            snapCarousel.scrollTo({ left: snapCarousel.offsetWidth, behavior: 'smooth' });
        });
    }
});
