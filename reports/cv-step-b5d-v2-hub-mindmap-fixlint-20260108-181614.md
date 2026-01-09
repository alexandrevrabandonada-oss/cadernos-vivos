# CV — B5d v0_4 — Fix lint (React Compiler deps)

- when: 
20260108-181614
- file: src/components/v2/Cv2MindmapHubClient.tsx

## Changes
- focus() -> useCallback deps [nodes.length]
- onKeyDown deps -> [active, focus]

## Verify
- OK