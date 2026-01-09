import React from "react";

export function V2ZenStamp(props: { size?: number; title?: string }) {
  const size = typeof props.size === "number" ? props.size : 16;
  const title = typeof props.title === "string" ? props.title : "Selo zen";

  return (
    <svg
      width={size}
      height={size}
      viewBox="0 0 32 32"
      role="img"
      aria-label={title}
      style={{ display: "block" }}
    >
      <title>{title}</title>

      {/* círculo “imperfeito” */}
      <path
        d="M16 3.4c7.6 0 12.9 5.2 12.9 12.7 0 7.2-5 12.5-12.7 12.5C8.7 28.6 3.2 23.6 3.2 16 3.2 8.7 8.5 3.4 16 3.4z"
        fill="none"
        stroke="currentColor"
        strokeWidth="2.6"
        strokeLinecap="round"
        strokeLinejoin="round"
      />

      {/* “rasgo” interno tipo pincel */}
      <path
        d="M9.3 18.2c2.6 2.1 5 3.2 7.3 3.2 2.5 0 4.7-1.3 6.9-3.9"
        fill="none"
        stroke="currentColor"
        strokeWidth="2.1"
        strokeLinecap="round"
        strokeLinejoin="round"
        opacity="0.7"
      />
    </svg>
  );
}