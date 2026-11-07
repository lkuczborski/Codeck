enum SlideMediaLayout {
    static let script =
        """
        (function() {
          const slide = document.querySelector('.slide');
          const content = slide?.querySelector('.slide-content');
          if (!content) return;
          const media = Array.from(content.querySelectorAll('img, video'));
          if (!media.length) return;
          let scheduled = false;

          function fitMedia() {
            scheduled = false;
            const slideStyle = getComputedStyle(slide);
            // client/offset dimensions are logical CSS pixels, unaffected by the preview transform.
            const availableHeight = slide.clientHeight - parseFloat(slideStyle.paddingTop) - parseFloat(slideStyle.paddingBottom);
            // Measure containers without intrinsic media forcing table columns wider than the slide.
            media.forEach(element => {
              element.style.width = '0px';
              element.style.height = '0px';
            });
            const sizes = media.map(element => {
              const width = element.naturalWidth || element.videoWidth || 300;
              const height = element.naturalHeight || element.videoHeight || 150;
              let parent = element.parentElement;
              let style = getComputedStyle(parent);
              while (parent !== content && (style.display === 'inline' || style.display === 'contents')) {
                parent = parent.parentElement;
                style = getComputedStyle(parent);
              }
              const parentWidth = parent.clientWidth - parseFloat(style.paddingLeft) - parseFloat(style.paddingRight);
              const scale = Math.min(1, Math.max(0, Math.min(parentWidth, content.clientWidth)) / width);
              return { element, width: width * scale, height: height * scale };
            });

            function applyScale(scale) {
              sizes.forEach(({element, width, height}) => {
                element.style.width = (width * scale) + 'px';
                element.style.height = (height * scale) + 'px';
              });
            }
            applyScale(1);
            if (content.offsetHeight <= availableHeight) return;

            // Measure the complete flow, including headings, captions, margins and other media.
            // One common scale preserves the relative sizes and aspect ratios of all media.
            let low = 0;
            let high = 1;
            for (let step = 0; step < 16; step++) {
              const scale = (low + high) / 2;
              applyScale(scale);
              if (content.offsetHeight <= availableHeight) low = scale;
              else high = scale;
            }
            applyScale(low);
          }

          function scheduleFit() {
            if (scheduled) return;
            scheduled = true;
            // Hidden previews also need to settle before they are shown; their animation frames may be suspended.
            queueMicrotask(fitMedia);
          }
          media.forEach(element => {
            element.addEventListener('load', scheduleFit);
            element.addEventListener('loadedmetadata', scheduleFit);
            element.addEventListener('error', scheduleFit);
          });
          window.addEventListener('resize', scheduleFit);
          window.addEventListener('load', scheduleFit);
          document.fonts?.ready.then(scheduleFit);
          new ResizeObserver(scheduleFit).observe(slide);
          fitMedia();
        })();
        """
}
