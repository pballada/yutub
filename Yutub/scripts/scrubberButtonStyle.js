(function() {
    const style = document.createElement('style');
    style.innerHTML = `
    .ytp-scrubber-button {
        width: 20px !important;
        height: 20px !important;
        border-radius: 10px !important;
        transform: translate(-5px, -5px) !important;
    }
    .ytp-scrubber-button:focus {
        background-color: darkred !important;
    }
    `;
    document.head.appendChild(style);
})(); 