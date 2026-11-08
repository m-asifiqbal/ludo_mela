// Ludo Mela animal avatars: one source of truth, injected into every artboard by apply_avatars.js.
// Each part is [d, fill, stroke, strokeWidth, animClass, transformOrigin] in a 48×48 box.
const E = (cx, cy, rx, ry) => `M${+(cx - rx).toFixed(2)} ${cy}a${rx} ${ry} 0 1 0 ${+(2 * rx).toFixed(2)} 0a${rx} ${ry} 0 1 0 ${+(-2 * rx).toFixed(2)} 0z`;
const C = (cx, cy, r) => E(cx, cy, r, r);
const BODY = 'M8 48c2-7 8-10 16-10s14 3 16 10z';
const SHADE = ['M0 30Q24 18 48 30V48H0z', 'rgba(0,0,0,.12)'];
const eyes = (l, r, y, rx, ry, col) => [
  [E(l, y, rx, ry) + E(r, y, rx, ry), col || '#1B1B1B', 0, 0, 'blink', `24px ${y}px`],
  [C(l + rx * 0.35, y - ry * 0.35, 0.75) + C(r + rx * 0.35, y - ry * 0.35, 0.75), '#FFFFFF', 0, 0, 'blink', `24px ${y}px`]
];
const cheeks = (l, r, y) => [[E(l, y, 2.2, 1.4) + E(r, y, 2.2, 1.4), 'rgba(255,110,130,.45)']];

const ANIMALS = {
  cat: ['#FFB02E', [
    SHADE, [BODY, '#DDE2EC', '#6B7389', 0.8],
    ['M15 40q9 4 18 0l-.5 2.5q-8.5 3.5-17 0z', '#E8322B'], [C(24, 43.6, 1.6), '#FFC61F', '#B26400', 0.5],
    ['M10.5 22L12 7.5l9.5 7z', '#F2F4F8', '#6B7389', 1.2, 'earl', '15px 20px'], ['M12.6 18.5l.8-7.6 4.6 3.6z', '#FFB3C7', 0, 0, 'earl', '15px 20px'],
    ['M37.5 22L36 7.5l-9.5 7z', '#F2F4F8', '#6B7389', 1.2, 'earr', '33px 20px'], ['M35.4 18.5l-.8-7.6-4.6 3.6z', '#FFB3C7', 0, 0, 'earr', '33px 20px'],
    [E(24, 27, 14.5, 12.5), '#F2F4F8', '#6B7389', 1.2], ['M24 14.6q6 .3 8.5 5q-4.5 1.6-8.5-1.2z', '#F59A23'],
    [E(18.5, 26, 2.4, 2.9) + E(29.5, 26, 2.4, 2.9), '#3FAE5A', 0, 0, 'blink', '24px 26px'],
    [E(18.5, 26, 1, 2.2) + E(29.5, 26, 1, 2.2), '#1B1B1B', 0, 0, 'blink', '24px 26px'],
    [C(19.3, 25, 0.7) + C(30.3, 25, 0.7), '#FFFFFF', 0, 0, 'blink', '24px 26px'],
    ['M22.7 30.3h2.6l-1.3 1.5z', '#FF7A9A'], ['M24 31.8v1M22 33.4q1 1 2 0q1 1 2 0', 0, '#6B7389', 1.1],
    ['M8 29.5l6 .8M8.5 32.5l5.5-.6M40 29.5l-6 .8M39.5 32.5l-5.5-.6', 0, '#9AA2B5', 0.9], ...cheeks(14.8, 33.2, 31)
  ]],
  tiger: ['#47BA2B', [
    SHADE, [BODY, '#E07A10', '#7A3E0E', 0.8], ['M19 48q1-6 5-7q4 1 5 7z', '#FFF3E0'],
    [C(13, 14, 5.5), '#F59A23', '#7A3E0E', 1.2, 'earl', '13px 19px'], [C(13, 14.4, 2.8), '#FFD9B0', 0, 0, 'earl', '13px 19px'],
    [C(35, 14, 5.5), '#F59A23', '#7A3E0E', 1.2, 'earr', '35px 19px'], [C(35, 14.4, 2.8), '#FFD9B0', 0, 0, 'earr', '35px 19px'],
    [E(24, 27, 15, 12.5), '#F59A23', '#7A3E0E', 1.2],
    ['M24 15.5v4.5M19.5 16.5l1.2 3.5M28.5 16.5l-1.2 3.5', 0, '#3A2006', 2],
    ['M9.5 25.5h4M10 30l3.5-1.2M38.5 25.5h-4M38 30l-3.5-1.2', 0, '#3A2006', 1.8],
    [E(24, 32, 7.5, 5.5), '#FFF3E0'], ...eyes(18.5, 29.5, 25.5, 2.1, 2.5),
    ['M21.6 29.6h4.8l-2.4 2.6z', '#E0607A', '#7A3E0E', 0.6], ['M24 32.2v1.6M21.3 34.2q1.35 1.4 2.7 0q1.35 1.4 2.7 0', 0, '#3A2006', 1.2]
  ]],
  parrot: ['#FFC61F', [
    SHADE, ['M8 48c2-8 8-11 16-11s14 3 16 11z', '#2E9A1B'], ['M30 41q6 1 9 7h-7z', '#1F7A12'],
    ['M21 13q-1-7 3-9q0 4 2 6q1-4 5-4q-2 3-2 7z', '#FF3FA4', '#B0125E', 0.8, 'earl', '24px 13px'],
    [E(24, 25, 13, 13.5), '#47BA2B', '#1D6B0F', 1.2], [E(18, 24, 4.6, 5) + E(30, 24, 4.6, 5), '#FFFFFF'],
    ...eyes(18, 30, 24, 2, 2.4), [E(13.5, 29.5, 2, 1.4) + E(34.5, 29.5, 2, 1.4), '#FF5A4E'],
    ['M19.5 29q4.5-4 9 0q-.5 4.5-4.5 6.5q-4-2-4.5-6.5z', '#FF8A1F', '#A84A00', 1], ['M21 31.5q3 1.2 6 0', 0, '#A84A00', 1]
  ]],
  hare: ['#2F95F2', [
    SHADE, [BODY, '#E2DED8', '#8E8A9A', 0.8],
    [E(17.5, 11, 4, 10), '#F4F1EE', '#8E8A9A', 1.2, 'earl', '17.5px 20px'], [E(17.5, 11.5, 2, 7), '#FFB3C7', 0, 0, 'earl', '17.5px 20px'],
    [E(30.5, 11, 4, 10), '#F4F1EE', '#8E8A9A', 1.2, 'earr', '30.5px 20px'], [E(30.5, 11.5, 2, 7), '#FFB3C7', 0, 0, 'earr', '30.5px 20px'],
    [E(24, 29, 13.5, 12), '#F4F1EE', '#8E8A9A', 1.2], ['M11.3 24q12.7-6 25.4 0l-.6 3.2q-12.1-5.4-24.2 0z', '#FF3FA4'],
    ...eyes(19, 29, 29.5, 2, 2.4), ['M22.6 33h2.8l-1.4 1.6z', '#FF7A9A'],
    ['M23 36h2v1.8h-2z', '#FFFFFF', '#8E8A9A', 0.5], ['M24 34.6v1.2M22 35.8q1 .8 2 0q1 .8 2 0', 0, '#6B6676', 1], ...cheeks(15, 33, 33)
  ]],
  fox: ['#FF7AA8', [
    SHADE, [BODY, '#E8661E'], ['M18 48q2-7 6-8q4 1 6 8z', '#FFF3E8'],
    ['M10 22L12 6l9 9z', '#F0782A', '#8A3A0A', 1.2, 'earl', '15px 19px'], ['M11.2 12.5L12 6l3.6 3.6z', '#3A2006', 0, 0, 'earl', '15px 19px'],
    ['M38 22L36 6l-9 9z', '#F0782A', '#8A3A0A', 1.2, 'earr', '33px 19px'], ['M36.8 12.5L36 6l-3.6 3.6z', '#3A2006', 0, 0, 'earr', '33px 19px'],
    ['M9 24q0-11 15-11t15 11q-2 10-15 14q-13-4-15-14z', '#F0782A', '#8A3A0A', 1.2],
    ['M9.5 25q6 0 9 4q2 4 5.5 7.5q-11-1-14.5-11.5zM38.5 25q-6 0-9 4q-2 4-5.5 7.5q11-1 14.5-11.5z', '#FFF3E8'],
    ...eyes(18.5, 29.5, 24, 1.9, 2.4), [E(24, 33, 2, 1.5), '#2A1A12'], ['M22.3 35q1.7 1.2 3.4 0', 0, '#8A3A0A', 1]
  ]],
  panda: ['#FF8A3D', [
    SHADE, [BODY, '#2A2A33'], ['M17 48q2-6 7-7q5 1 7 7z', '#FFFFFF'],
    [C(12.5, 15, 5), '#2A2A33', 0, 0, 'earl', '12.5px 20px'], [C(35.5, 15, 5), '#2A2A33', 0, 0, 'earr', '35.5px 20px'],
    [E(24, 27, 14.5, 12.5), '#FFFFFF', '#5E5E6B', 1.2],
    ['M14.5 24.5q2-4.5 6-3q2 2-.5 6.5q-3 3-5 1q-1.5-1.5-.5-4.5zM33.5 24.5q-2-4.5-6-3q-2 2 .5 6.5q3 3 5 1q1.5-1.5.5-4.5z', '#2A2A33'],
    [C(18.3, 25.5, 1.7) + C(29.7, 25.5, 1.7), '#FFFFFF', 0, 0, 'blink', '24px 25.5px'],
    [C(18.6, 25.7, 1) + C(30, 25.7, 1), '#1B1B1B', 0, 0, 'blink', '24px 25.5px'],
    [E(24, 30.5, 2.2, 1.5), '#2A2A33'], ['M24 32v1.4M22.2 34q.9 1 1.8 0q.9 1 1.8 0', 0, '#2A2A33', 1.1], ...cheeks(13.8, 34.2, 31)
  ]],
  elephant: ['#9B6BFF', [
    SHADE, [BODY, '#8F9BB3'], ['M10 46q14-8 28 0v2H10z', '#FF3FA4'],
    [E(11, 26, 7.5, 10), '#A9B4C8', '#5E6C88', 1.2, 'earl', '17px 26px'], [E(11.5, 26, 4.5, 7), '#F2B8C6', 0, 0, 'earl', '17px 26px'],
    [E(37, 26, 7.5, 10), '#A9B4C8', '#5E6C88', 1.2, 'earr', '31px 26px'], [E(36.5, 26, 4.5, 7), '#F2B8C6', 0, 0, 'earr', '31px 26px'],
    [E(24, 24, 11.5, 11), '#A9B4C8', '#5E6C88', 1.2],
    ['M21 29q0 6 1 9q1 3 3.5 2.5q2-.5 1.5-2.5q-1.5-.5-1.5-3q0-3 .5-6z', '#A9B4C8', '#5E6C88', 1.1],
    ...eyes(19.5, 28.5, 22.5, 1.6, 2), [E(16.5, 28, 1.8, 1.2) + E(31.5, 28, 1.8, 1.2), 'rgba(255,110,130,.45)'],
    ['M15.8 22.5a3.7 3.7 0 1 0 7.4 0a3.7 3.7 0 1 0-7.4 0zM24.8 22.5a3.7 3.7 0 1 0 7.4 0a3.7 3.7 0 1 0-7.4 0zM23.2 22.3h1.6', 0, '#3A2416', 1.2]
  ]],
  owl: ['#14B8C8', [
    SHADE, ['M9 48c1-8 7-11 15-11s14 3 15 11z', '#8A5A3A'], ['M17 48q1-7 7-8q6 1 7 8z', '#E8C9A0'],
    ['M11 16L10 6l7 6z', '#8A5A3A', 0, 0, 'earl', '13px 15px'], ['M37 16l1-10-7 6z', '#8A5A3A', 0, 0, 'earr', '35px 15px'],
    [E(24, 25, 14, 13), '#A0704A', '#5A3A20', 1.2], [E(18, 25, 6, 6.2) + E(30, 25, 6, 6.2), '#F3E3C8'],
    [C(18, 25, 3.4) + C(30, 25, 3.4), '#FFB800', 0, 0, 'blink', '24px 25px'], [C(18, 25, 1.9) + C(30, 25, 1.9), '#1B1B1B', 0, 0, 'blink', '24px 25px'],
    [C(18.8, 24.1, 0.7) + C(30.8, 24.1, 0.7), '#FFFFFF', 0, 0, 'blink', '24px 25px'],
    ['M22.4 29l1.6 3.6 1.6-3.6z', '#FF8A1F'], ['M12.5 19q5.5-3 10 1.5M35.5 19q-5.5-3-10 1.5', 0, '#5A3A20', 1.4]
  ]],
  photo: ['#8FC9F0', [
    [C(37, 11, 4), '#FFE27A'], ['M0 34q12-8 24-2t24-4V48H0z', '#6AB04C'],
    ['M10 48q2-12 14-12t14 12z', '#3D86E0'], [C(24, 23, 7), '#E8B48A'], ['M17 22q0-9 7-9t7 9q-3-4-7-4t-7 4z', '#3A2416'],
    ...eyes(21.5, 26.5, 24, 0.9, 1.1, '#2A1A12'), ['M22 27.2q2 1.6 4 0', 0, '#7A2E1A', 1]
  ]]
};
const AV_OF = { you: 'cat', raja: 'tiger', mitu: 'parrot', tara: 'hare', bot: 'hare', nadia: 'fox', rafi: 'panda', nani: 'elephant', golu: 'owl' };
const NAMES = { cat: 'Mishti the cat', tiger: 'Bagha the tiger', parrot: 'Mitu the parrot', hare: 'Tara the hare', fox: 'Lali the fox', panda: 'Golu the panda', elephant: 'Haati the elephant', owl: 'Pecha the owl', photo: 'Your photo' };

// The literal block every artboard gets.
function source(extraFnName) {
  const lib = {};
  for (const k of Object.keys(ANIMALS)) lib[k] = [ANIMALS[k][0], ANIMALS[k][1].map((p) => p.map((v) => (v === undefined ? 0 : v)))];
  return [
    '// Animal avatars (shared set — see the design system board). Parts: [d, fill, stroke, width, anim, origin].',
    'const ANIMALS = ' + JSON.stringify(lib) + ';',
    'const AV_OF = ' + JSON.stringify(AV_OF) + ';',
    'const AV_NAMES = ' + JSON.stringify(NAMES) + ';',
    'function avatar(kind) {',
    "  const a = ANIMALS[AV_OF[kind || 'you'] || kind] || ANIMALS.cat;",
    "  return [{ d: 'M0 0h48v48H0z', f: a[0], s: 'none', w: 0, c: '', o: '24px 24px' }].concat(a[1].map((p) => ({ d: p[0], f: p[1] || 'none', s: p[2] || 'none', w: p[3] || 0, c: p[4] ? 'av-' + p[4] : '', o: p[5] || '24px 24px' })));",
    '}'
  ].concat(extraFnName ? ['function ' + extraFnName + '(kind) { return avatar(kind); }'] : []).join('\n');
}
const CSS = '.av-blink,.av-earl,.av-earr{transform-box:view-box}.av-blink{animation:avBlink 4.2s infinite}.av-earl{animation:avEarL 5s infinite}.av-earr{animation:avEarR 5s 1.4s infinite}'
  + '@keyframes avBlink{0%,93%,100%{transform:scaleY(1)}96%{transform:scaleY(.1)}}'
  + '@keyframes avEarL{0%,84%,100%{transform:rotate(0)}88%{transform:rotate(-9deg)}93%{transform:rotate(5deg)}}'
  + '@keyframes avEarR{0%,84%,100%{transform:rotate(0)}88%{transform:rotate(9deg)}93%{transform:rotate(-5deg)}}';
module.exports = { ANIMALS, AV_OF, NAMES, source, CSS };
