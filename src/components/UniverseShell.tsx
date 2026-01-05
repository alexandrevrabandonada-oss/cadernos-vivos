"use client";

import React from "react";
import { useParams } from "next/navigation";

function moodFromSlug(slug: string): string {
  const s = (slug || "").toLowerCase();

  if (s.indexOf("poluicao") >= 0) return "smoke";
  if (s.indexOf("trabalho") >= 0) return "steel";
  if (s.indexOf("memoria") >= 0) return "archive";
  if (s.indexOf("eco") >= 0) return "green";

  return "urban";
}

function normalizeMood(s: string): string {
  const v = (s || "").trim().toLowerCase();
  if (!v) return "";
  return v.replace(/[^a-z0-9\-]/g, "-").replace(/\-+/g, "-").replace(/^\-|\-$/g, "");
}

type Props = {
  children: React.ReactNode;
  slug?: string;
  mood?: string;
};

export default function UniverseShell({ children, slug: slugProp, mood: moodProp }: Props) {
  const params = useParams() as { slug?: string };
  const slug = slugProp ? String(slugProp) : (params && params.slug ? String(params.slug) : "");

  const normalized = normalizeMood(moodProp || "");
  const mood = normalized ? normalized : moodFromSlug(slug);

  const cls = "cv-universe cv-mood-" + mood;

  return (
    <div className={cls} data-cv-slug={slug} data-cv-mood={mood}>
      <div className="cv-universe-inner">
        {children}
      </div>
    </div>
  );
}