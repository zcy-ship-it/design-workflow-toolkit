/** Conversion adapters implement this contract; UI components do not depend on an engine. */
export type ViewId = "front" | "rear" | "left" | "right" | "top" | "bottom";
export interface GeometrySummary {
  triangles: number;
  meshes: number;
  materials: number;
}
export interface ConversionResult {
  glb: ArrayBuffer;
  report: {
    sourceName: string;
    target: "glb2";
    before: GeometrySummary;
    after: GeometrySummary;
    warnings: string[];
  };
}
export interface ConversionOptions {
  signal?: AbortSignal;
  onProgress?: (progress: { stage: string; ratio?: number }) => void;
}
export interface ModelConverter {
  id: string;
  supportedExtensions: readonly string[];
  convert(
    files: readonly File[],
    options?: ConversionOptions,
  ): Promise<ConversionResult>;
}
export interface VectorExportOptions {
  view: ViewId;
  width: number;
  height: number;
  detail: "large" | "medium" | "fine";
  texture: "pattern" | "expanded";
}
export interface VectorExportResult {
  svg: string;
  groups: number;
  paths: number;
  warnings: string[];
}
