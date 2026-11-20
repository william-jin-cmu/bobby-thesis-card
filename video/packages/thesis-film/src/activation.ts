import { assertAttributes, assertEmptyElement, createMarkupSurfaceFacet, textAttribute } from "@hypit/hypit/markup";
import { canonicalize, sameType } from "@hypit/hypit/protocol";
import { sealGraphFragment } from "@hypit/hypit/author";
import { createAdmissionPackageFacet } from "@hypit/hypit/admission";
import { createProducerPackageFacet } from "@hypit/hypit/producer";
import type { ProducerPackage } from "@hypit/hypit/producer";
import type { AdmissionPackage } from "@hypit/hypit/admission";
import type { ModuleManifest, TypeRef } from "@hypit/hypit/protocol";
import type { StructuredSurfaceHandler, SurfaceResolvedReference } from "@hypit/hypit/markup";
import { compositionTypes } from "@hypit/composition";
import { mediaTypes } from "@hypit/media";
import type { FontStackRef, SynchronizedMedia } from "@hypit/media";
import { timelineTypes } from "@hypit/timeline";
import type { Timeline } from "@hypit/timeline";
import { spatialTypes } from "@hypit/spatial";
import type { SpatialFrame } from "@hypit/spatial";
import { temporalTypes } from "@hypit/temporal";
import type { TemporalWindow } from "@hypit/temporal";
import { resolveTemporalContext, resolveTemporalWindowReference, temporalContextAttributeVocabulary,
  temporalWindowAttributeNames, temporalWindowAttributeVocabulary } from "@hypit/temporal/markup";
import { CLIP_KEYS, renderThesisFilm } from "./render.ts";
import type { ClipKey, FilmOptions } from "./render.ts";

/**
 * One coordinated film scene: the Bobby phone, its eight screen recordings, the camera moves,
 * captions, step rail, callouts, hook and outro all share one frame-driven HTML visual.
 */
const module = { name: "@bobby/thesis-film", version: "1" } as const;
const optionsType: TypeRef = { module, name: "FilmOptions" };
const producer = { module, name: "render" };
const fontInputs = ["serif", "sans", "sansm"] as const;
const inputs = [
  { name: "timeline", type: timelineTypes.timeline }, { name: "within", type: spatialTypes.frame },
  { name: "window", type: temporalTypes.window }, { name: "options", type: optionsType },
  ...fontInputs.map(name => ({ name, type: mediaTypes.fontStack })),
  ...CLIP_KEYS.map(name => ({ name, type: mediaTypes.synchronized })),
];
export const manifest: ModuleManifest = { format: "hypit.module@1", ...module,
  dependencies: [compositionTypes.visualTrack, mediaTypes.fontStack, timelineTypes.timeline,
    spatialTypes.frame, temporalTypes.window].map(type => ({ module: type.module })),
  types: [{ name: optionsType.name }], capabilities: [],
  producers: [{ name: producer.name, inputs, outputs: [{ name: "visual", type: compositionTypes.visualTrack }], needs: [] }],
};
const fragment = sealGraphFragment({ inputs, operations: [{ id: "render", producer,
  inputs: Object.fromEntries(inputs.map(input => [input.name, { kind: "fragment-input" as const, name: input.name }])),
  result: { kind: "output", name: "visual" } }],
  exports: [{ name: "visual", type: compositionTypes.visualTrack, root: { kind: "fragment-operation", operation: "render" } }],
});
const inline = <T>(record: { value: { kind: string; value?: unknown } } | undefined): T => {
  if (record?.value.kind !== "inline") throw new Error("Thesis film inputs must be inline values.");
  return record.value.value as T;
};
const component: ProducerPackage & AdmissionPackage = { producers: [{ producer, handler: ({ inputs: i }) => {
  const clips = Object.fromEntries(CLIP_KEYS.map(key => [key, inline<SynchronizedMedia>(i[key])])) as Record<ClipKey, SynchronizedMedia>;
  const track = renderThesisFilm(inline<Timeline>(i.timeline), inline<SpatialFrame>(i.within), inline<TemporalWindow>(i.window),
    { serif: inline<FontStackRef>(i.serif), sans: inline<FontStackRef>(i.sans), sansm: inline<FontStackRef>(i.sansm) },
    clips, inline<FilmOptions>(i.options));
  return { needs: {}, outputs: { visual: { kind: "inline", value: canonicalize(track) } } };
} }] };

export const decodeSurface: StructuredSurfaceHandler = ({ element, resolveReference }) => {
  assertAttributes(element, ["id", "timeline", "within", "z", ...fontInputs, ...CLIP_KEYS, ...temporalWindowAttributeNames]);
  assertEmptyElement(element);
  const id = textAttribute(element, "id");
  const reference = (name: string, type: TypeRef): SurfaceResolvedReference => {
    const raw = element.attributes[name];
    if (typeof raw !== "object" || raw.kind !== "reference") throw new Error(`${name} must be a reference.`);
    const found = resolveReference(raw.path);
    if (found === undefined || !sameType(found.type, type)) throw new Error(`${name} has the wrong type.`);
    return found;
  };
  const context = resolveTemporalContext({ element, resolveReference });
  const window = resolveTemporalWindowReference({ element, resolveReference });
  const options: FilmOptions = { id, z: Number(element.attributes.z ?? "0") };
  const bindings: Record<string, SurfaceResolvedReference["ref"]> = {
    timeline: context.timeline.ref, within: reference("within", spatialTypes.frame).ref, window: window.ref,
    options: { kind: "record", id: `${id}.options` },
  };
  for (const name of fontInputs) bindings[name] = reference(name, mediaTypes.fontStack).ref;
  for (const name of CLIP_KEYS) bindings[name] = reference(name, mediaTypes.synchronized).ref;
  return { records: [{ id: `${id}.options`, type: optionsType, value: { kind: "inline", value: canonicalize(options) }, range: element.range }],
    fragments: [fragment],
    components: [{ id, fragment: fragment.id, inputs: bindings, outputs: { visual: `${id}.visual` }, range: element.range }],
    exports: [`${id}.visual`] };
};

const declaration = { name: "film", tag: "Film", mode: "structured" as const,
  outputs: [compositionTypes.visualTrack, optionsType],
  vocabulary: { summary: "The Bobby 观点卡 product film: phone recordings, camera, captions, hook and outro in one scene.",
    attributes: [
      ...temporalContextAttributeVocabulary, ...temporalWindowAttributeVocabulary,
      { name: "id", kind: "literal" as const, required: true, summary: "id" },
      { name: "z", kind: "literal" as const, required: false, summary: "Paint order among Film contributions." },
      { name: "within", kind: "reference" as const, required: true, accepts: [spatialTypes.frame], summary: "Canvas frame" },
      ...fontInputs.map(name => ({ name, kind: "reference" as const, required: true, accepts: [mediaTypes.fontStack], summary: `${name} font stack` })),
      ...CLIP_KEYS.map(name => ({ name, kind: "reference" as const, required: true, accepts: [mediaTypes.synchronized], summary: `${name} recording` })),
    ],
    ports: [{ name: "visual", type: compositionTypes.visualTrack, summary: "The complete film picture." }],
    example: '<bobby:Film id="film" timeline={program.timeline} during={program.window} within={canvas.bounds} serif={serif} sans={sans} sansm={sansm} home={home.media} .../>',
  },
};
export const hypitPackage = { format: "hypit.package@1" as const, modules: [{ manifest }],
  facets: [createProducerPackageFacet(component), createAdmissionPackageFacet(component),
    createMarkupSurfaceFacet({ module, declaration, handler: decodeSurface })] };
export default hypitPackage;
