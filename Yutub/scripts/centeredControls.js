// ==UserScript==
// @name         YouTube Center Controls (Trusted Types-safe)
// @match        https://www.youtube.com/*
// ==/UserScript==

(function () {
  'use strict';

  // Trusted Types policy to allow safe HTML insertion
  const htmlPolicy = window.trustedTypes?.createPolicy?.('youtube-center-controls', {
    createHTML: (html) => html
  });

  const setHTML = (el, html) => {
    el.innerHTML = htmlPolicy ? htmlPolicy.createHTML(html) : html;
  };

  const centerControls = document.createElement('div');
  centerControls.id = 'center-youtube-controls';
  centerControls.style.cssText = `
    position: absolute;
    top: 50%;
    left: 50%;
    transform: translate(-50%, -50%);
    display: flex;
    gap: 20px;
    z-index: 1000;
    opacity: 0;
    visibility: hidden;
    transition: opacity 0.3s ease, visibility 0.3s ease;
    pointer-events: none;
  `;

  const buttonStyle = `
    background: rgba(0, 0, 0, 0.8);
    border: none;
    border-radius: 50%;
    width: 60px;
    height: 60px;
    color: white;
    cursor: pointer;
    display: flex;
    align-items: center;
    justify-content: center;
    font-size: 24px;
    transition: all 0.2s ease;
    pointer-events: auto;
    transform: scale(1);
    box-shadow: 0 0 10px rgba(0, 0, 0, 0.5);
  `;

  const prevBtn = document.createElement('button');
  const playBtn = document.createElement('button');
  const nextBtn = document.createElement('button');

  [prevBtn, playBtn, nextBtn].forEach((btn) => {
    btn.style.cssText = buttonStyle;
    btn.tabIndex = 0;
  });

  prevBtn.title = 'Previous';
  playBtn.title = 'Play/Pause';
  nextBtn.title = 'Next';

  setHTML(prevBtn, `
    <svg width="40" height="40" viewBox="0 0 40 40" fill="none" xmlns="http://www.w3.org/2000/svg">
      <path d="M13 10h3v20h-3zm5 10l12 8V12z" fill="currentColor"/>
    </svg>`);

  setHTML(playBtn, `
    <svg width="40" height="40" viewBox="0 0 40 40" fill="none" xmlns="http://www.w3.org/2000/svg">
      <circle cx="20" cy="20" r="20" fill="none"/>
      <path d="M16 13v14l12-7-12-7z" fill="currentColor"/>
    </svg>`);

  setHTML(nextBtn, `
    <svg width="40" height="40" viewBox="0 0 40 40" fill="none" xmlns="http://www.w3.org/2000/svg">
      <path d="M27 30h-3V10h3zm-5-10l-12-8v16z" fill="currentColor"/>
    </svg>`);

  [prevBtn, playBtn, nextBtn].forEach((btn) => {
    btn.addEventListener('focus', () => {
      btn.style.background = 'rgba(0, 0, 0, 0.95)';
      btn.style.transform = 'scale(1.1)';
      btn.style.boxShadow = '0 0 20px rgba(0, 0, 0, 0.8)';
      centerControls.style.opacity = '1';
      centerControls.style.visibility = 'visible';
    });

    btn.addEventListener('blur', () => {
      btn.style.background = 'rgba(0, 0, 0, 0.8)';
      btn.style.transform = 'scale(1)';
      btn.style.boxShadow = '0 0 10px rgba(0, 0, 0, 0.5)';
      setTimeout(syncControlsVisibility, 100);
    });
  });

  centerControls.appendChild(prevBtn);
  centerControls.appendChild(playBtn);
  centerControls.appendChild(nextBtn);

  let originalPlay = null;
  let lastClickTime = 0;

  function handlePlayPause(e) {
    if (e.detail > 1) return;
    const now = Date.now();
    if (now - lastClickTime < 250) return;
    lastClickTime = now;

    e.preventDefault();
    togglePlayPause();
  }

  playBtn.addEventListener('click', handlePlayPause);

  function togglePlayPause() {
    const video = document.querySelector('video');
    if (!video) return;

    console.log('Video paused state:', video.paused);
    if (video.paused) {
      video.play();
    } else {
      video.pause();
    }
  }

  function updatePlayButton() {
    const video = document.querySelector('video');
    if (!video) return;

    setHTML(playBtn, video.paused
      ? `<svg width="40" height="40" viewBox="0 0 40 40" fill="none" xmlns="http://www.w3.org/2000/svg">
           <circle cx="20" cy="20" r="20" fill="none"/>
           <path d="M16 13v14l12-7-12-7z" fill="currentColor"/>
         </svg>`
      : `<svg width="40" height="40" viewBox="0 0 40 40" fill="none" xmlns="http://www.w3.org/2000/svg">
           <circle cx="20" cy="20" r="20" fill="none"/>
           <rect x="15" y="13" width="4" height="14" fill="currentColor"/>
           <rect x="21" y="13" width="4" height="14" fill="currentColor"/>
         </svg>`);
  }

  function syncControlsVisibility() {
    const originalControls = document.querySelector('.ytp-chrome-bottom');
    if (!originalControls) return;

    const style = window.getComputedStyle(originalControls);
    const opacity = parseFloat(style.opacity);
    const display = style.display;

    if (display === 'none' || opacity === 0) {
      centerControls.style.opacity = '0';
      centerControls.style.visibility = 'hidden';
    } else {
      centerControls.style.opacity = opacity.toString();
      centerControls.style.visibility = 'visible';
    }
  }

  function initializeCenterControls() {
    const player = document.querySelector('.html5-video-player') || document.querySelector('#movie_player');
    const originalControls = document.querySelector('.ytp-chrome-bottom');

    if (!player || !originalControls) {
      setTimeout(initializeCenterControls, 1000);
      return;
    }

    if (player.contains(centerControls)) return;
    player.appendChild(centerControls);

    const originalPrev = document.querySelector('.ytp-prev-button');
    originalPlay = document.querySelector('.ytp-play-button');
    const originalNext = document.querySelector('.ytp-next-button');

    [originalPrev, originalPlay, originalNext].forEach(btn => {
      if (btn) btn.style.visibility = 'hidden';
    });

    const ytPlayer = document.querySelector('#movie_player');
    prevBtn.addEventListener('click', () => ytPlayer && ytPlayer.previousVideo && ytPlayer.previousVideo());
    nextBtn.addEventListener('click', () => ytPlayer && ytPlayer.nextVideo && ytPlayer.nextVideo());

    const video = document.querySelector('video');
    if (video) {
      video.addEventListener('play', updatePlayButton);
      video.addEventListener('pause', updatePlayButton);
      updatePlayButton();
    }

    const observer = new MutationObserver(syncControlsVisibility);
    observer.observe(originalControls, { attributes: true, attributeFilter: ['style', 'class'] });

    const parent = originalControls.parentElement;
    if (parent) {
      observer.observe(parent, { attributes: true, attributeFilter: ['style', 'class'] });
    }

    if ('ResizeObserver' in window) {
      const resizeObserver = new ResizeObserver(syncControlsVisibility);
      resizeObserver.observe(originalControls);
    }

    syncControlsVisibility();
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', initializeCenterControls);
  } else {
    initializeCenterControls();
  }

  let currentUrl = location.href;
  new MutationObserver(() => {
    if (location.href !== currentUrl) {
      currentUrl = location.href;
      setTimeout(initializeCenterControls, 1000);
    }
  }).observe(document, { subtree: true, childList: true });
})();
