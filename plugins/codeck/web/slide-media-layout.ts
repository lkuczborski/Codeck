// Keep the fitting algorithm aligned with CodeckCore/Rendering/SlideMediaLayout.swift.
// This trusted bundled code runs after sanitization; incoming renderer scripts never run.
export function fitSlideMedia(root: ShadowRoot): () => void {
  const slide = root.querySelector<HTMLElement>('.slide');
  const content = slide?.querySelector<HTMLElement>('.slide-content');
  if (!slide || !content) return () => {};
  const media = [...content.querySelectorAll<HTMLImageElement | HTMLVideoElement>('img, video')];
  if (!media.length) return () => {};
  let scheduled = false;
  let disposed = false;

  function fitMedia() {
    scheduled = false;
    if (disposed || !slide!.isConnected) return;
    const slideStyle = getComputedStyle(slide!);
    // Logical CSS pixels are unaffected by the surrounding preview/thumbnail transform.
    const availableHeight = slide!.clientHeight - parseFloat(slideStyle.paddingTop) - parseFloat(slideStyle.paddingBottom);
    media.forEach(element => {
      element.style.width = '0px';
      element.style.height = '0px';
    });
    const sizes = media.map(element => {
      const width = (element instanceof HTMLImageElement ? element.naturalWidth : element.videoWidth) || 300;
      const height = (element instanceof HTMLImageElement ? element.naturalHeight : element.videoHeight) || 150;
      let parent = element.parentElement!;
      let style = getComputedStyle(parent);
      while (parent !== content && (style.display === 'inline' || style.display === 'contents')) {
        parent = parent.parentElement!;
        style = getComputedStyle(parent);
      }
      const parentWidth = parent.clientWidth - parseFloat(style.paddingLeft) - parseFloat(style.paddingRight);
      const scale = Math.min(1, Math.max(0, Math.min(parentWidth, content!.clientWidth)) / width);
      return { element, width: width * scale, height: height * scale };
    });
    function applyScale(scale: number) {
      sizes.forEach(({ element, width, height }) => {
        element.style.width = `${width * scale}px`;
        element.style.height = `${height * scale}px`;
      });
    }
    applyScale(1);
    if (content!.offsetHeight <= availableHeight) return;
    // Measure the complete text/media flow, then reduce media together to preserve proportions.
    let low = 0;
    let high = 1;
    for (let step = 0; step < 16; step++) {
      const scale = (low + high) / 2;
      applyScale(scale);
      if (content!.offsetHeight <= availableHeight) low = scale;
      else high = scale;
    }
    applyScale(low);
  }

  function scheduleFit() {
    if (disposed || scheduled) return;
    scheduled = true;
    queueMicrotask(fitMedia);
  }
  const events = ['load', 'loadedmetadata', 'error'];
  media.forEach(element => events.forEach(event => element.addEventListener(event, scheduleFit)));
  window.addEventListener('resize', scheduleFit);
  document.fonts?.ready.then(scheduleFit);
  const observer = new ResizeObserver(scheduleFit);
  observer.observe(slide);
  // Navigator thumbnails are mounted before insertion into the document.
  scheduleFit();
  return () => {
    disposed = true;
    observer.disconnect();
    window.removeEventListener('resize', scheduleFit);
    media.forEach(element => events.forEach(event => element.removeEventListener(event, scheduleFit)));
  };
}
