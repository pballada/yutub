 (function syncCustomControls() {
   /* ---------  Grab stock elements  --------- */
   const player        = document.getElementById('movie_player');
   const ytControls    = document.querySelector('.ytp-chrome-controls');
   const progressBar   = document.querySelector('.ytp-progress-bar-container');
   const timeDisplay   = document.querySelector('.ytp-time-contents');
   const chromeBottom  = document.querySelector('.ytp-chrome-bottom');

   if (!player || !ytControls || !progressBar || !timeDisplay || !chromeBottom) {
     console.warn('[YT-UI] Some elements are still missing, retrying…');
     return setTimeout(syncCustomControls, 500);   // try again in ½ s
   }

   /* ---------  Create custom containers  --------- */
   const topRight = Object.assign(document.createElement('div'), {
     id: 'custom-top-right-controls',
     style: `
       position:absolute;top:0;right:0;display:flex;gap:10px;align-items:center;
       height:48px;padding:6px 12px;
       background:linear-gradient(to bottom,rgba(0,0,0,.5),rgba(0,0,0,0));
       transition:opacity .25s ease;z-index:1000;opacity:1;
     `
   });
   topRight.appendChild(ytControls);

   const timeWrap = Object.assign(document.createElement('div'), {
     id: 'custom-time-contents-wrapper',
     style: `
       position:absolute;left:12px;bottom:10px;
       transition:opacity .25s ease;z-index:1000;opacity:1;
     `
   });
   timeWrap.appendChild(timeDisplay);

   /* ---------  Mount  --------- */
   player.style.position = 'relative';
   player.append(topRight, timeWrap);

   /* Shift progress bar up by 40 px */
   Object.assign(progressBar.style, {
     position:'absolute', bottom:'40px', left:0, right:0, width:'100%', zIndex:999
   });

   /* ---------  Visibility synchronisation  --------- */
   const setVisibility = (shown) => {
     const o = shown ? '1' : '0';
     const p = shown ? 'auto' : 'none';
     topRight.style.opacity = o;    topRight.style.pointerEvents = p;
     timeWrap.style.opacity = o;    timeWrap.style.pointerEvents = p;
   };

   /* Primary detector – MutationObserver */
   const observer = new MutationObserver(() => {
     update();      // run immediately on any attribute/class change
   });
   observer.observe(chromeBottom, { attributes:true, attributeFilter:['class','aria-hidden'] });

   /* Fallback detector – rAF polling (handles opacity-only tweens) */
   let lastShownState = true;
   function update() {
     const styleOp   = parseFloat(getComputedStyle(chromeBottom).opacity);
     const hiddenAr  = chromeBottom.getAttribute('aria-hidden') === 'true';
     const autoHide  = chromeBottom.classList.contains('ytp-autohide');
     const shown = !(hiddenAr || autoHide || styleOp < 0.05);

     if (shown !== lastShownState) {
       setVisibility(shown);
       lastShownState = shown;
     }
     requestAnimationFrame(update);
   }
   update();  // kick off first frame
 })();
