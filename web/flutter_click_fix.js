// Flutter Web Click Fix for Trackpad Issues
// This fixes the gesture detection problems on Flutter web with macOS trackpads

(function() {
    console.log('[Flutter Click Fix] Initializing...');

    // Wait for Flutter to be ready
    let attempts = 0;
    const maxAttempts = 50;

    function initializeClickFix() {
        attempts++;

        // Check if Flutter canvas is ready
        const flutterView = document.querySelector('flt-glass-pane');

        if (!flutterView && attempts < maxAttempts) {
            setTimeout(initializeClickFix, 200);
            return;
        }

        if (!flutterView) {
            console.error('[Flutter Click Fix] Could not find Flutter view');
            return;
        }

        console.log('[Flutter Click Fix] Flutter view found, applying fixes...');

        // Fix 1: Ensure proper pointer events
        flutterView.style.pointerEvents = 'auto';

        // Fix 2: Add fallback click handling
        let lastClickTime = 0;
        let clickCount = 0;

        document.addEventListener('click', function(e) {
            const now = Date.now();
            if (now - lastClickTime > 500) {
                clickCount = 0;
            }
            clickCount++;
            lastClickTime = now;

            // Log clicks for debugging
            console.log(`[Flutter Click Fix] Click detected #${clickCount} at (${e.clientX}, ${e.clientY})`);

            // Force a synthetic pointer event if needed
            if (e.target && e.target.tagName === 'FLT-GLASS-PANE') {
                const pointerEvent = new PointerEvent('pointerdown', {
                    bubbles: true,
                    cancelable: true,
                    clientX: e.clientX,
                    clientY: e.clientY,
                    pointerType: 'mouse',
                    pointerId: 1
                });

                setTimeout(() => {
                    e.target.dispatchEvent(pointerEvent);

                    const pointerUpEvent = new PointerEvent('pointerup', {
                        bubbles: true,
                        cancelable: true,
                        clientX: e.clientX,
                        clientY: e.clientY,
                        pointerType: 'mouse',
                        pointerId: 1
                    });
                    e.target.dispatchEvent(pointerUpEvent);
                }, 10);
            }
        }, true);

        // Fix 3: Override trackpad wheel events that cause issues
        document.addEventListener('wheel', function(e) {
            // Check if this is from a trackpad (no discrete wheel delta)
            if (Math.abs(e.deltaY) < 50 && e.deltaMode === 0) {
                // Small delta, likely trackpad - don't prevent default scrolling
                // but log for debugging
                console.log('[Flutter Click Fix] Trackpad scroll detected');
            }
        }, { passive: true });

        // Fix 4: Add CSS to ensure clickability
        const style = document.createElement('style');
        style.textContent = `
            flt-glass-pane {
                pointer-events: auto !important;
                touch-action: auto !important;
            }

            flt-scene-host {
                pointer-events: auto !important;
            }

            flt-scene {
                pointer-events: auto !important;
            }

            /* Ensure Flutter canvas is interactive */
            canvas {
                pointer-events: auto !important;
            }

            /* Fix for Safari */
            * {
                -webkit-tap-highlight-color: transparent;
            }
        `;
        document.head.appendChild(style);

        console.log('[Flutter Click Fix] All fixes applied successfully');

        // Monitor for Flutter navigation to ensure our fixes persist
        const observer = new MutationObserver(function(mutations) {
            const flutterView = document.querySelector('flt-glass-pane');
            if (flutterView && flutterView.style.pointerEvents !== 'auto') {
                flutterView.style.pointerEvents = 'auto';
                console.log('[Flutter Click Fix] Re-applied pointer events fix');
            }
        });

        observer.observe(document.body, {
            childList: true,
            subtree: true,
            attributes: true,
            attributeFilter: ['style']
        });
    }

    // Start initialization
    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', initializeClickFix);
    } else {
        initializeClickFix();
    }

    // Also hook into Flutter's initialization if available
    window.addEventListener('flutter-initialized', initializeClickFix);
    window.addEventListener('load', initializeClickFix);
})();