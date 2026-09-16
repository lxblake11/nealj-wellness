const observer = new IntersectionObserver(
  (entries) => {
    entries.forEach((entry) => {
      if (!entry.isIntersecting) return;

      entry.target.classList.add("is-visible");
      observer.unobserve(entry.target);
    });
  },
  {
    threshold: 0.08,
    rootMargin: "0px 0px -5% 0px",
  }
);

document
  .querySelectorAll(".reveal, .image-reveal, .line-mask")
  .forEach((element) => observer.observe(element));

const parallaxImages = [
  document.querySelector(".hero-image img"),
  document.querySelector(".image-break-photo img"),
  document.querySelector(".visit-image img"),
].filter(Boolean);

let ticking = false;

function updateMotion() {
  if (
    window.innerWidth < 701 ||
    window.matchMedia("(prefers-reduced-motion: reduce)").matches
  ) {
    ticking = false;
    return;
  }

  const viewportHeight = window.innerHeight;

  parallaxImages.forEach((image, index) => {
    const parent = image.parentElement;
    const rect = parent.getBoundingClientRect();

    if (rect.bottom <= 0 || rect.top >= viewportHeight) return;

    const progress =
      (viewportHeight - rect.top) /
      (viewportHeight + rect.height);

    const strength = index === 0 ? 5 : 3.5;
    const offset = (progress - 0.5) * strength;

    image.style.transform =
      `translateY(${offset}%) scale(1.035)`;
  });

  ticking = false;
}

window.addEventListener(
  "scroll",
  () => {
    if (ticking) return;

    ticking = true;
    window.requestAnimationFrame(updateMotion);
  },
  { passive: true }
);

document.querySelectorAll(".service").forEach((service) => {
  service.addEventListener("pointerenter", () => {
    service.dataset.hovered = "true";
  });

  service.addEventListener("pointerleave", () => {
    delete service.dataset.hovered;
  });
});

updateMotion();


const categoryNav = document.querySelector(".category-nav");

function updateCategoryNav() {
  if (!categoryNav) return;

  const scrollableHeight =
    document.documentElement.scrollHeight - window.innerHeight;

  const triggerPoint = scrollableHeight * 0.05;

  categoryNav.classList.toggle(
    "is-sticky",
    window.scrollY >= triggerPoint
  );
}

window.addEventListener(
  "scroll",
  updateCategoryNav,
  { passive: true }
);

window.addEventListener("resize", updateCategoryNav);

updateCategoryNav();
