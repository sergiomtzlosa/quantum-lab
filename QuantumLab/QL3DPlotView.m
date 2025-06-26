#import "QL3DPlotView.h"
#import "QLColorMap.h"
#import "QLPlotStyle.h"
#include <complex.h>
#include <math.h>

@implementation QL3DPlotView {
    SCNScene *_scene;
    SCNNode *_cameraPivot;
    SCNNode *_cameraNode;
    SCNNode *_contentRoot;
    SCNNode *_surfaceNode;
    SCNNode *_cursorNode;
    SCNNode *_currentPointNode;
    NSTextField *_hud;
    CFAbsoluteTime _lastSurfaceBuild;
    NSInteger _lastRenderedFrame;
    QLPlotKind _builtKind;
}

- (instancetype)initWithFrame:(NSRect)frameRect {
    self = [super initWithFrame:frameRect];
    if (self) {
        _options = [QLPlotOptions new];
        _frameIndex = 0;
        _lastRenderedFrame = -1;
        _builtKind = (QLPlotKind)-1;
        [self setupScene];
    }
    return self;
}

- (void)setupScene {
    _scene = [SCNScene scene];
    self.scene = _scene;
    self.backgroundColor = [NSColor.controlBackgroundColor colorUsingColorSpace:NSColorSpace.sRGBColorSpace];
    self.allowsCameraControl = YES;
    self.autoenablesDefaultLighting = NO;
    self.antialiasingMode = SCNAntialiasingModeMultisampling4X;
    self.jitteringEnabled = YES;

    _cameraPivot = [SCNNode node];
    [_scene.rootNode addChildNode:_cameraPivot];
    SCNCamera *camera = [SCNCamera camera];
    camera.fieldOfView = 38.0;
    camera.zNear = 0.01;
    camera.zFar = 100.0;
    _cameraNode = [SCNNode node];
    _cameraNode.camera = camera;
    _cameraNode.position = SCNVector3Make(0, 0, 6.0);
    [_cameraPivot addChildNode:_cameraNode];
    _cameraPivot.eulerAngles = SCNVector3Make(-0.38, 0.62, 0);
    self.pointOfView = _cameraNode;

    SCNLight *ambient = [SCNLight light];
    ambient.type = SCNLightTypeAmbient;
    ambient.color = [NSColor colorWithWhite:0.95 alpha:1];
    ambient.intensity = 900;
    SCNNode *ambientNode = [SCNNode node];
    ambientNode.light = ambient;
    [_scene.rootNode addChildNode:ambientNode];

    SCNLight *key = [SCNLight light];
    key.type = SCNLightTypeDirectional;
    key.color = [NSColor colorWithWhite:0.98 alpha:1];
    key.intensity = 1250;
    SCNNode *keyNode = [SCNNode node];
    keyNode.light = key;
    keyNode.position = SCNVector3Make(4, 6, 5);
    keyNode.eulerAngles = SCNVector3Make(-0.7, 0.6, 0);
    [_scene.rootNode addChildNode:keyNode];

    SCNLight *fill = [SCNLight light];
    fill.type = SCNLightTypeDirectional;
    fill.color = [NSColor colorWithWhite:0.82 alpha:1];
    fill.intensity = 600;
    SCNNode *fillNode = [SCNNode node];
    fillNode.light = fill;
    fillNode.position = SCNVector3Make(-5, 3, 6);
    fillNode.eulerAngles = SCNVector3Make(0.4, -0.5, 0);
    [_scene.rootNode addChildNode:fillNode];

    _contentRoot = [SCNNode node];
    _contentRoot.name = @"content";
    [_scene.rootNode addChildNode:_contentRoot];

    _hud = [NSTextField labelWithString:@""];
    _hud.font = [NSFont monospacedDigitSystemFontOfSize:11 weight:NSFontWeightRegular];
    _hud.textColor = NSColor.labelColor;
    _hud.drawsBackground = YES;
    _hud.backgroundColor = [NSColor.windowBackgroundColor colorWithAlphaComponent:0.78];
    _hud.translatesAutoresizingMaskIntoConstraints = NO;
    _hud.maximumNumberOfLines = 3;
    [self addSubview:_hud];

    NSButton *centerButton = [NSButton buttonWithTitle:@"Center" target:self action:@selector(centerView:)];
    centerButton.bezelStyle = NSBezelStyleRounded;
    centerButton.controlSize = NSControlSizeSmall;
    centerButton.font = [NSFont systemFontOfSize:11];
    centerButton.toolTip = @"Center and reset the 3D camera";
    centerButton.accessibilityLabel = @"Center 3D camera";
    centerButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:centerButton];

    [NSLayoutConstraint activateConstraints:@[
        [_hud.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:12],
        [_hud.topAnchor constraintEqualToAnchor:self.topAnchor constant:12],
        [_hud.widthAnchor constraintLessThanOrEqualToConstant:460],
        [centerButton.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-12],
        [centerButton.topAnchor constraintEqualToAnchor:self.topAnchor constant:12],
        [centerButton.widthAnchor constraintGreaterThanOrEqualToConstant:76]
    ]];
}

- (void)viewDidChangeEffectiveAppearance {
    [super viewDidChangeEffectiveAppearance];
    self.backgroundColor = [NSColor.controlBackgroundColor colorUsingColorSpace:NSColorSpace.sRGBColorSpace];
    _hud.textColor = NSColor.labelColor;
    _hud.backgroundColor = [NSColor.windowBackgroundColor colorWithAlphaComponent:0.78];
}

- (void)centerView:(id)sender {
    [self resetCamera];
    [self setNeedsDisplay:YES];
}

- (void)resetCamera {
    _cameraPivot.position = SCNVector3Zero;
    _cameraPivot.scale = SCNVector3Make(1, 1, 1);
    _cameraNode.eulerAngles = SCNVector3Zero;
    [self applyDefaultCamera];
    self.pointOfView = _cameraNode;
    if (self.defaultCameraController) {
        [self.defaultCameraController stopInertia];
        self.defaultCameraController.pointOfView = _cameraNode;
        self.defaultCameraController.target = SCNVector3Zero;
        self.defaultCameraController.automaticTarget = NO;
    }
}

- (void)applyDefaultCamera {
    if (!self.result || self.result.isSchrodinger) {
        _cameraPivot.eulerAngles = SCNVector3Make(-0.62, 0.70, 0);
        _cameraNode.position = SCNVector3Make(0, 0, 6.0);
    } else if (self.result.isSpin) {
        _cameraPivot.eulerAngles = SCNVector3Make(-0.30, 0.55, 0);
        _cameraNode.position = SCNVector3Make(0, 0, 5.8);
    } else {
        _cameraPivot.eulerAngles = SCNVector3Make(-0.42, 0.65, 0);
        _cameraNode.position = SCNVector3Make(0, 0, 6.6);
    }
}

- (void)setResult:(QLSimulationResult *)result {
    _result = result;
    _frameIndex = 0;
    _lastRenderedFrame = -1;
    [self applyDefaultCamera];
    [self rebuildScene];
}

- (void)setOptions:(QLPlotOptions *)options {
    BOOL meshChanged = (_options.meshResolution != options.meshResolution);
    BOOL colorChanged = ![_options.colorMapName isEqualToString:options.colorMapName];
    _options = [options copy];
    [self updateAutoRotate];
    if ((meshChanged || colorChanged) && self.result.is2D) {
        [self rebuildSurfaceForCurrentFrameForce:YES];
    } else if (colorChanged && self.result.isSchrodinger && !self.result.is2D) {
        [self rebuildScene];
    }
    [self updateHUD];
}

- (void)setFrameIndex:(NSInteger)frameIndex {
    NSInteger count = self.result.frameCount;
    if (count < 1) count = 1;
    _frameIndex = MIN(MAX(0, frameIndex), count - 1);
    if (!self.result) return;

    if (self.result.isSchrodinger && !self.result.is2D) {
        [self updateTimeCursor];
    } else if (self.result.is2D) {
        [self rebuildSurfaceForCurrentFrameForce:NO];
    } else {
        [self updateCurrentPoint];
    }
    [self updateHUD];
}

- (void)clearSceneContent {
    [_contentRoot removeAllActions];
    for (SCNNode *child in _contentRoot.childNodes.copy) {
        [child removeFromParentNode];
    }
    _surfaceNode = nil;
    _cursorNode = nil;
    _currentPointNode = nil;
}

- (void)rebuildScene {
    [self clearSceneContent];
    if (!self.result) {
        _hud.stringValue = @"No simulation loaded";
        return;
    }
    _builtKind = self.result.plotKind;
    _lastRenderedFrame = -1;
    if (self.result.isSchrodinger && !self.result.is2D) {
        [self buildSpacetimeSurface];
    } else if (self.result.is2D) {
        [self buildSurfaceAxes];
        [self rebuildSurfaceForCurrentFrameForce:YES];
    } else if (self.result.isSpin) {
        [self buildBlochSphere];
    } else if (self.result.isOscillator) {
        [self buildOscillatorCurve];
    }
    [self updateHUD];
    [self updateAutoRotate];
}

- (void)updateAutoRotate {
    if (!_contentRoot) return;
    [_contentRoot removeActionForKey:@"autoRotate"];
    if (self.options.autoRotate) {
        SCNAction *rotate = [SCNAction repeatActionForever:[SCNAction rotateByX:0 y:2.0 * M_PI z:0 duration:24.0]];
        [_contentRoot runAction:rotate forKey:@"autoRotate"];
    }
}

- (void)updateHUD {
    if (!self.result) {
        _hud.stringValue = @"No simulation loaded";
        return;
    }
    double t = self.result.frameCount > 0
        ? self.result.times[(NSUInteger)MIN(self.frameIndex, self.result.frameCount - 1)].doubleValue : 0.0;
    if (self.result.isSchrodinger) {
        NSString *dim = self.result.is2D ? @"2D" : @"1D";
        _hud.stringValue = [NSString stringWithFormat:@"Schrödinger %@   t = %.3f / %.3f\n|ψ|² max = %.4g   grid %ld×%ld",
                            dim, t, self.result.tmax,
                            self.result.globalDensityMax,
                            (long)self.result.nx, (long)self.result.ny];
    } else if (self.result.isSpin) {
        _hud.stringValue = [NSString stringWithFormat:@"Bloch sphere   t = %.3f / %.3f\nTrajectory shows Sx, Sy, Sz",
                            t, self.result.tmax];
    } else {
        _hud.stringValue = [NSString stringWithFormat:@"Phase space   t = %.3f / %.3f\nCurve: (t, x, p)",
                            t, self.result.tmax];
    }
}

#pragma mark - Geometry helpers

- (NSString *)stringForVector:(SCNVector3)v {
    return [NSString stringWithFormat:@"(%.2f, %.2f, %.2f)", v.x, v.y, v.z];
}

- (SCNNode *)lineNodeWithPoints:(NSArray<NSValue *> *)points color:(NSColor *)color {
    NSUInteger count = points.count;
    if (count < 2) return [SCNNode node];
    SCNVector3 *vertices = calloc(count, sizeof(SCNVector3));
    for (NSUInteger i = 0; i < count; i++) {
        vertices[i] = points[i].SCNVector3Value;
    }
    SCNGeometrySource *source = [SCNGeometrySource geometrySourceWithVertices:vertices count:(NSInteger)count];
    NSUInteger segmentCount = count - 1;
    uint32_t *indices = calloc(segmentCount * 2, sizeof(uint32_t));
    for (NSUInteger i = 0; i < segmentCount; i++) {
        indices[i * 2] = (uint32_t)i;
        indices[i * 2 + 1] = (uint32_t)(i + 1);
    }
    NSData *indexData = [NSData dataWithBytes:indices length:segmentCount * 2 * sizeof(uint32_t)];
    SCNGeometryElement *element = [SCNGeometryElement geometryElementWithData:indexData
                                                                primitiveType:SCNGeometryPrimitiveTypeLine
                                                               primitiveCount:(NSInteger)(count - 1)
                                                                bytesPerIndex:sizeof(uint32_t)];
    SCNGeometry *geometry = [SCNGeometry geometryWithSources:@[source] elements:@[element]];
    SCNMaterial *material = [SCNMaterial material];
    material.lightingModelName = SCNLightingModelConstant;
    material.diffuse.contents = color;
    material.emission.contents = color;
    material.writesToDepthBuffer = NO;
    geometry.materials = @[material];
    free(vertices);
    free(indices);
    return [SCNNode nodeWithGeometry:geometry];
}

- (SCNNode *)tubeNodeWithPoints:(NSArray<NSValue *> *)points radius:(CGFloat)radius color:(NSColor *)color {
    NSUInteger count = points.count;
    if (count < 2) return [SCNNode node];
    const NSUInteger sides = 6;
    NSUInteger vertexCount = count * sides;
    SCNVector3 *vertices = calloc(vertexCount, sizeof(SCNVector3));
    SCNVector3 *normals = calloc(vertexCount, sizeof(SCNVector3));
    NSUInteger segmentCount = count - 1;
    uint32_t *indices = calloc(segmentCount * sides * 6, sizeof(uint32_t));
    if (!vertices || !normals || !indices) {
        free(vertices); free(normals); free(indices);
        return [SCNNode node];
    }

    for (NSUInteger i = 0; i < count; i++) {
        SCNVector3 p = points[i].SCNVector3Value;
        SCNVector3 prev = points[i == 0 ? 0 : i - 1].SCNVector3Value;
        SCNVector3 next = points[i + 1 == count ? count - 1 : i + 1].SCNVector3Value;
        CGFloat tx = next.x - prev.x, ty = next.y - prev.y, tz = next.z - prev.z;
        CGFloat tl = sqrt(tx * tx + ty * ty + tz * tz);
        if (tl < 1e-9) { tx = 0; ty = 0; tz = 1; tl = 1; }
        tx /= tl; ty /= tl; tz /= tl;
        CGFloat ux = 0, uy = 1, uz = 0;
        if (fabs(ty) > 0.92) { ux = 1; uy = 0; uz = 0; }
        CGFloat nx = ty * uz - tz * uy;
        CGFloat ny = tz * ux - tx * uz;
        CGFloat nz = tx * uy - ty * ux;
        CGFloat nl = sqrt(nx * nx + ny * ny + nz * nz);
        nx /= nl; ny /= nl; nz /= nl;
        CGFloat bx = ty * nz - tz * ny;
        CGFloat by = tz * nx - tx * nz;
        CGFloat bz = tx * ny - ty * nx;

        for (NSUInteger s = 0; s < sides; s++) {
            CGFloat angle = 2.0 * M_PI * (CGFloat)s / (CGFloat)sides;
            CGFloat ca = cos(angle), sa = sin(angle);
            CGFloat ox = nx * ca + bx * sa;
            CGFloat oy = ny * ca + by * sa;
            CGFloat oz = nz * ca + bz * sa;
            NSUInteger index = i * sides + s;
            vertices[index] = SCNVector3Make(p.x + ox * radius, p.y + oy * radius, p.z + oz * radius);
            normals[index] = SCNVector3Make(ox, oy, oz);
        }
    }

    NSUInteger indexCursor = 0;
    for (NSUInteger i = 0; i < segmentCount; i++) {
        for (NSUInteger s = 0; s < sides; s++) {
            uint32_t a = (uint32_t)(i * sides + s);
            uint32_t b = (uint32_t)(i * sides + (s + 1) % sides);
            uint32_t c = (uint32_t)((i + 1) * sides + s);
            uint32_t d = (uint32_t)((i + 1) * sides + (s + 1) % sides);
            indices[indexCursor++] = a;
            indices[indexCursor++] = b;
            indices[indexCursor++] = c;
            indices[indexCursor++] = b;
            indices[indexCursor++] = d;
            indices[indexCursor++] = c;
        }
    }

    SCNGeometrySource *positionSource = [SCNGeometrySource geometrySourceWithVertices:vertices count:(NSInteger)vertexCount];
    SCNGeometrySource *normalSource = [SCNGeometrySource geometrySourceWithNormals:normals count:(NSInteger)vertexCount];
    NSData *indexData = [NSData dataWithBytes:indices length:indexCursor * sizeof(uint32_t)];
    SCNGeometryElement *element = [SCNGeometryElement geometryElementWithData:indexData
                                                                primitiveType:SCNGeometryPrimitiveTypeTriangles
                                                               primitiveCount:(NSInteger)(indexCursor / 3)
                                                                bytesPerIndex:sizeof(uint32_t)];
    SCNGeometry *geometry = [SCNGeometry geometryWithSources:@[positionSource, normalSource] elements:@[element]];
    SCNMaterial *material = [SCNMaterial material];
    material.lightingModelName = SCNLightingModelConstant;
    material.diffuse.contents = color;
    material.emission.contents = color;
    material.doubleSided = YES;
    geometry.materials = @[material];
    free(vertices); free(normals); free(indices);
    return [SCNNode nodeWithGeometry:geometry];
}

- (SCNNode *)torusNodeWithRadius:(CGFloat)ringRadius pipeRadius:(CGFloat)pipeRadius color:(NSColor *)color {
    SCNTorus *torus = [SCNTorus torusWithRingRadius:MAX(ringRadius, 0.001) pipeRadius:pipeRadius];
    torus.ringSegmentCount = 96;
    torus.pipeSegmentCount = 6;
    SCNMaterial *material = [SCNMaterial material];
    material.lightingModelName = SCNLightingModelConstant;
    material.diffuse.contents = color;
    material.emission.contents = color;
    torus.materials = @[material];
    return [SCNNode nodeWithGeometry:torus];
}

- (SCNNode *)textNode:(NSString *)text at:(SCNVector3)position color:(NSColor *)color {
    SCNText *geometry = [SCNText textWithString:text extrusionDepth:0.01];
    geometry.font = [NSFont systemFontOfSize:0.42 weight:NSFontWeightMedium];
    geometry.flatness = 0.15;
    geometry.materials.firstObject.diffuse.contents = color ?: NSColor.secondaryLabelColor;
    geometry.materials.firstObject.emission.contents = color ?: NSColor.secondaryLabelColor;
    SCNNode *node = [SCNNode nodeWithGeometry:geometry];
    node.position = position;
    node.scale = SCNVector3Make(0.26, 0.26, 0.26);
    SCNBillboardConstraint *billboard = [SCNBillboardConstraint billboardConstraint];
    billboard.freeAxes = SCNBillboardAxisY;
    node.constraints = @[billboard];
    return node;
}

- (void)addAxesForSurface {
    NSArray *xPoints = @[[NSValue valueWithSCNVector3:SCNVector3Make(-1.15, 0, -1.12)],
                         [NSValue valueWithSCNVector3:SCNVector3Make(1.15, 0, -1.12)]];
    NSArray *zPoints = @[[NSValue valueWithSCNVector3:SCNVector3Make(1.12, 0, -1.15)],
                         [NSValue valueWithSCNVector3:SCNVector3Make(1.12, 0, 1.15)]];
    NSArray *yPoints = @[[NSValue valueWithSCNVector3:SCNVector3Make(-1.12, 0, -1.12)],
                         [NSValue valueWithSCNVector3:SCNVector3Make(-1.12, 0.95, -1.12)]];
    NSColor *axisColor = [NSColor.labelColor colorWithAlphaComponent:0.8];
    [_contentRoot addChildNode:[self tubeNodeWithPoints:xPoints radius:0.005 color:axisColor]];
    [_contentRoot addChildNode:[self tubeNodeWithPoints:zPoints radius:0.005 color:axisColor]];
    [_contentRoot addChildNode:[self tubeNodeWithPoints:yPoints radius:0.005 color:axisColor]];
    [_contentRoot addChildNode:[self textNode:@"x" at:SCNVector3Make(1.18, 0, -1.12) color:axisColor]];
    [_contentRoot addChildNode:[self textNode:@"t" at:SCNVector3Make(1.12, 0, 1.2) color:axisColor]];
    [_contentRoot addChildNode:[self textNode:@"|ψ|²" at:SCNVector3Make(-1.12, 1.05, -1.12) color:axisColor]];

    for (NSInteger i = -5; i <= 5; i++) {
        CGFloat v = (CGFloat)i / 5.0;
        NSArray *lineX = @[[NSValue valueWithSCNVector3:SCNVector3Make(v, -0.005, -1.1)],
                           [NSValue valueWithSCNVector3:SCNVector3Make(v, -0.005, 1.1)]];
        [_contentRoot addChildNode:[self lineNodeWithPoints:lineX
                                                      color:[NSColor.separatorColor colorWithAlphaComponent:0.18]]];
        NSArray *lineZ = @[[NSValue valueWithSCNVector3:SCNVector3Make(-1.1, -0.005, v)],
                           [NSValue valueWithSCNVector3:SCNVector3Make(1.1, -0.005, v)]];
        [_contentRoot addChildNode:[self lineNodeWithPoints:lineZ
                                                      color:[NSColor.separatorColor colorWithAlphaComponent:0.18]]];
    }
}

- (NSImage *)surfaceGradientImageForColorMap:(QLColorMap *)colorMap {
    return [NSImage imageWithSize:NSMakeSize(256, 1) flipped:NO drawingHandler:^BOOL(NSRect rect) {
        for (NSInteger i = 0; i < 256; i++) {
            double t = (double)i / 255.0;
            NSColor *color = [colorMap colorAtUnit:0.32 + 0.68 * t];
            color = [color blendedColorWithFraction:0.08 ofColor:NSColor.whiteColor] ?: color;
            [color setFill];
            NSRectFill(NSMakeRect((CGFloat)i, 0, 1, 1));
        }
        return YES;
    }];
}

- (SCNNode *)surfaceNodeWithColumns:(NSInteger)cols
                              rows:(NSInteger)rows
                           heights:(const double *)heights
                          maxHeight:(double)maxHeight
                          colorMap:(QLColorMap *)colorMap {
    if (cols < 2 || rows < 2) return [SCNNode node];
    NSInteger count = cols * rows;
    SCNVector3 *positions = calloc((size_t)count, sizeof(SCNVector3));
    SCNVector3 *normals = calloc((size_t)count, sizeof(SCNVector3));
    CGPoint *uvs = calloc((size_t)count, sizeof(CGPoint));
    if (!positions || !normals || !uvs) {
        free(positions); free(normals); free(uvs);
        return [SCNNode node];
    }
    double safeMax = fmax(maxHeight, 1e-12);
    for (NSInteger row = 0; row < rows; row++) {
        for (NSInteger col = 0; col < cols; col++) {
            NSInteger index = row * cols + col;
            double h = heights[index] / safeMax;
            double x = -1.0 + 2.0 * (double)col / (double)(cols - 1);
            double z = -1.0 + 2.0 * (double)row / (double)(rows - 1);
            positions[index] = SCNVector3Make((float)x, (float)(h * 0.9), (float)z);
            uvs[index] = CGPointMake(h, 0.5);
            double hL = heights[row * cols + MAX(0, col - 1)] / safeMax;
            double hR = heights[row * cols + MIN(cols - 1, col + 1)] / safeMax;
            double hD = heights[MAX(0, row - 1) * cols + col] / safeMax;
            double hU = heights[MIN(rows - 1, row + 1) * cols + col] / safeMax;
            double dhdx = (hR - hL) * 0.5;
            double dhdz = (hU - hD) * 0.5;
            double nx = -dhdx * 3.0;
            double nz = -dhdz * 3.0;
            double length = sqrt(nx * nx + 1.0 + nz * nz);
            normals[index] = SCNVector3Make((float)(nx / length), (float)(1.0 / length), (float)(nz / length));
        }
    }
    NSMutableData *indexData = [NSMutableData dataWithCapacity:(NSUInteger)((cols - 1) * (rows - 1) * 6 * sizeof(uint32_t))];
    for (NSInteger row = 0; row < rows - 1; row++) {
        for (NSInteger col = 0; col < cols - 1; col++) {
            uint32_t i0 = (uint32_t)(row * cols + col);
            uint32_t i1 = (uint32_t)(row * cols + col + 1);
            uint32_t i2 = (uint32_t)((row + 1) * cols + col);
            uint32_t i3 = (uint32_t)((row + 1) * cols + col + 1);
            uint32_t indices[6] = {i0, i1, i2, i1, i3, i2};
            [indexData appendBytes:indices length:sizeof(indices)];
        }
    }
    SCNGeometrySource *posSource = [SCNGeometrySource geometrySourceWithVertices:positions count:count];
    SCNGeometrySource *normalSource = [SCNGeometrySource geometrySourceWithNormals:normals count:count];
    SCNGeometrySource *uvSource = [SCNGeometrySource geometrySourceWithTextureCoordinates:uvs count:count];
    SCNGeometryElement *element = [SCNGeometryElement geometryElementWithData:indexData
                                                                primitiveType:SCNGeometryPrimitiveTypeTriangles
                                                               primitiveCount:(cols - 1) * (rows - 1) * 2
                                                                bytesPerIndex:sizeof(uint32_t)];
    SCNGeometry *geometry = [SCNGeometry geometryWithSources:@[posSource, normalSource, uvSource] elements:@[element]];
    NSImage *gradient = [self surfaceGradientImageForColorMap:colorMap];
    SCNMaterial *material = [SCNMaterial material];
    material.lightingModelName = SCNLightingModelBlinn;
    material.diffuse.contents = gradient;
    material.diffuse.intensity = 1.0;
    material.diffuse.wrapS = SCNWrapModeClamp;
    material.diffuse.wrapT = SCNWrapModeClamp;
    material.diffuse.magnificationFilter = SCNFilterModeLinear;
    material.emission.contents = gradient;
    material.emission.intensity = 0.30;
    material.specular.contents = [NSColor colorWithWhite:0.35 alpha:1];
    material.shininess = 0.15;
    material.doubleSided = YES;
    material.roughness.contents = @0.85;
    geometry.materials = @[material];
    free(positions); free(normals); free(uvs);
    return [SCNNode nodeWithGeometry:geometry];
}

- (void)buildSpacetimeSurface {
    QLSimulationResult *result = self.result;
    NSInteger nx = result.nx;
    NSInteger stride = MAX(1, (NSInteger)ceil((double)nx / 256.0));
    NSInteger cols = (nx + stride - 1) / stride;
    NSInteger rows = result.frameCount;
    double *heights = calloc((size_t)(cols * rows), sizeof(double));
    if (!heights) return;
    double maxH = 0.0;
    for (NSInteger row = 0; row < rows; row++) {
        const double complex *psi = [result wavefunctionAtFrame:row];
        for (NSInteger col = 0; col < cols; col++) {
            NSInteger i = MIN(nx - 1, col * stride);
            double d = psi ? creal(psi[i] * conj(psi[i])) : 0.0;
            heights[row * cols + col] = d;
            if (d > maxH) maxH = d;
        }
    }
    QLColorMap *map = [QLColorMap colorMapNamed:self.options.colorMapName];
    _surfaceNode = [self surfaceNodeWithColumns:cols rows:rows heights:heights maxHeight:maxH colorMap:map];
    [_contentRoot addChildNode:_surfaceNode];
    free(heights);

    SCNPlane *plane = [SCNPlane planeWithWidth:2.18 height:1.0];
    SCNMaterial *planeMaterial = [SCNMaterial material];
    planeMaterial.diffuse.contents = [NSColor.systemRedColor colorWithAlphaComponent:0.16];
    planeMaterial.emission.contents = [NSColor.systemRedColor colorWithAlphaComponent:0.20];
    planeMaterial.doubleSided = YES;
    planeMaterial.writesToDepthBuffer = NO;
    plane.materials = @[planeMaterial];
    _cursorNode = [SCNNode nodeWithGeometry:plane];
    _cursorNode.position = SCNVector3Make(0, 0.45, -1.0);
    [_contentRoot addChildNode:_cursorNode];

    [self addAxesForSurface];
    [self updateTimeCursor];
}

- (void)buildSurfaceAxes {
    NSArray *xPoints = @[[NSValue valueWithSCNVector3:SCNVector3Make(-1.15, 0, -1.15)],
                         [NSValue valueWithSCNVector3:SCNVector3Make(1.15, 0, -1.15)]];
    NSArray *zPoints = @[[NSValue valueWithSCNVector3:SCNVector3Make(1.12, 0, -1.15)],
                         [NSValue valueWithSCNVector3:SCNVector3Make(1.12, 0, 1.15)]];
    NSArray *yPoints = @[[NSValue valueWithSCNVector3:SCNVector3Make(-1.12, 0, -1.12)],
                         [NSValue valueWithSCNVector3:SCNVector3Make(-1.12, 0.95, -1.12)]];
    NSColor *axisColor = [NSColor.labelColor colorWithAlphaComponent:0.8];
    [_contentRoot addChildNode:[self tubeNodeWithPoints:xPoints radius:0.005 color:axisColor]];
    [_contentRoot addChildNode:[self tubeNodeWithPoints:zPoints radius:0.005 color:axisColor]];
    [_contentRoot addChildNode:[self tubeNodeWithPoints:yPoints radius:0.005 color:axisColor]];
    [_contentRoot addChildNode:[self textNode:@"x" at:SCNVector3Make(1.18, 0, -1.15) color:axisColor]];
    [_contentRoot addChildNode:[self textNode:@"y" at:SCNVector3Make(1.12, 0, 1.2) color:axisColor]];
    [_contentRoot addChildNode:[self textNode:@"|ψ|²" at:SCNVector3Make(-1.12, 1.05, -1.12) color:axisColor]];
}

- (void)rebuildSurfaceForCurrentFrameForce:(BOOL)force {
    if (!self.result.is2D) return;
    CFAbsoluteTime now = CFAbsoluteTimeGetCurrent();
    if (!force && _surfaceNode && _lastRenderedFrame == self.frameIndex) return;
    if (!force && _surfaceNode && now - _lastSurfaceBuild < 1.0 / 15.0) return;

    const float *density = [self.result densityAtFrame:self.frameIndex];
    if (!density) return;
    NSInteger nx = self.result.nx;
    NSInteger ny = self.result.ny;
    NSInteger target = MAX(32, MIN(192, self.options.meshResolution));
    NSInteger step = MAX(1, (NSInteger)ceil((double)MAX(nx, ny) / (double)target));
    NSInteger cols = (nx + step - 1) / step;
    NSInteger rows = (ny + step - 1) / step;
    double *heights = calloc((size_t)(cols * rows), sizeof(double));
    if (!heights) return;
    double maxH = 0.0;
    for (NSInteger row = 0; row < rows; row++) {
        NSInteger sy = MIN(ny - 1, row * step);
        for (NSInteger col = 0; col < cols; col++) {
            NSInteger sx = MIN(nx - 1, col * step);
            double d = density[sy * nx + sx];
            heights[row * cols + col] = d;
            if (d > maxH) maxH = d;
        }
    }
    QLColorMap *map = [QLColorMap colorMapNamed:self.options.colorMapName];
    SCNNode *newSurface = [self surfaceNodeWithColumns:cols rows:rows heights:heights maxHeight:maxH colorMap:map];
    if (_surfaceNode) [_surfaceNode removeFromParentNode];
    _surfaceNode = newSurface;
    [_contentRoot addChildNode:_surfaceNode];
    free(heights);
    _lastSurfaceBuild = now;
    _lastRenderedFrame = self.frameIndex;
}

- (void)updateTimeCursor {
    if (!_cursorNode || !self.result) return;
    NSInteger count = self.result.frameCount;
    if (count < 2) return;
    double z = -1.0 + 2.0 * (double)self.frameIndex / (double)(count - 1);
    _cursorNode.position = SCNVector3Make(0, 0.45, z);
}

- (void)buildBlochSphere {
    SCNSphere *sphere = [SCNSphere sphereWithRadius:1.0];
    sphere.segmentCount = 48;
    SCNMaterial *material = [SCNMaterial material];
    material.lightingModelName = SCNLightingModelConstant;
    material.diffuse.contents = [NSColor colorWithWhite:0.7 alpha:0.35];
    material.transparency = 0.52;
    material.doubleSided = YES;
    material.writesToDepthBuffer = NO;
    sphere.materials = @[material];
    SCNNode *sphereNode = [SCNNode nodeWithGeometry:sphere];
    [_contentRoot addChildNode:sphereNode];

    NSColor *wire = [NSColor.secondaryLabelColor colorWithAlphaComponent:0.72];
    for (NSInteger lat = -3; lat <= 3; lat++) {
        double y = (double)lat / 4.0;
        double r = sqrt(fmax(0.001, 1.0 - y * y));
        SCNNode *ring = [self torusNodeWithRadius:r pipeRadius:0.0045 color:wire];
        ring.position = SCNVector3Make(0, y, 0);
        [_contentRoot addChildNode:ring];
    }
    for (NSInteger lon = 0; lon < 8; lon++) {
        CGFloat angle = M_PI * (CGFloat)lon / 8.0;
        SCNNode *holder = [SCNNode node];
        holder.eulerAngles = SCNVector3Make(0, angle, 0);
        SCNNode *ring = [self torusNodeWithRadius:1.0 pipeRadius:0.0045 color:wire];
        ring.eulerAngles = SCNVector3Make(M_PI_2, 0, 0);
        [holder addChildNode:ring];
        [_contentRoot addChildNode:holder];
    }

    NSArray *axisX = @[[NSValue valueWithSCNVector3:SCNVector3Make(-1.2, 0, 0)],
                       [NSValue valueWithSCNVector3:SCNVector3Make(1.2, 0, 0)]];
    NSArray *axisY = @[[NSValue valueWithSCNVector3:SCNVector3Make(0, -1.2, 0)],
                       [NSValue valueWithSCNVector3:SCNVector3Make(0, 1.2, 0)]];
    NSArray *axisZ = @[[NSValue valueWithSCNVector3:SCNVector3Make(0, 0, -1.2)],
                       [NSValue valueWithSCNVector3:SCNVector3Make(0, 0, 1.2)]];
    NSColor *axisColor = [NSColor.labelColor colorWithAlphaComponent:0.8];
    [_contentRoot addChildNode:[self tubeNodeWithPoints:axisX radius:0.006 color:axisColor]];
    [_contentRoot addChildNode:[self tubeNodeWithPoints:axisY radius:0.006 color:axisColor]];
    [_contentRoot addChildNode:[self tubeNodeWithPoints:axisZ radius:0.006 color:axisColor]];
    [_contentRoot addChildNode:[self textNode:@"Sx" at:SCNVector3Make(1.25, 0, 0) color:axisColor]];
    [_contentRoot addChildNode:[self textNode:@"Sz" at:SCNVector3Make(0, 1.25, 0) color:axisColor]];
    [_contentRoot addChildNode:[self textNode:@"Sy" at:SCNVector3Make(0, 0, 1.25) color:axisColor]];

    QLSeries *sx = [self.result seriesNamed:@"Sx"];
    QLSeries *sy = [self.result seriesNamed:@"Sy"];
    QLSeries *sz = [self.result seriesNamed:@"Sz"];
    NSInteger count = MIN(sx.yValues.count, MIN(sy.yValues.count, sz.yValues.count));
    NSMutableArray *path = [NSMutableArray arrayWithCapacity:(NSUInteger)count];
    for (NSInteger i = 0; i < count; i++) {
        [path addObject:[NSValue valueWithSCNVector3:SCNVector3Make(
            (float)sx.yValues[(NSUInteger)i].doubleValue,
            (float)sz.yValues[(NSUInteger)i].doubleValue,
            (float)sy.yValues[(NSUInteger)i].doubleValue)]];
    }
    [_contentRoot addChildNode:[self tubeNodeWithPoints:path radius:0.007 color:NSColor.systemYellowColor]];
    SCNSphere *point = [SCNSphere sphereWithRadius:0.05];
    point.segmentCount = 16;
    SCNMaterial *pointMaterial = [SCNMaterial material];
    pointMaterial.lightingModelName = SCNLightingModelConstant;
    pointMaterial.diffuse.contents = NSColor.systemYellowColor;
    pointMaterial.emission.contents = NSColor.systemYellowColor;
    point.materials = @[pointMaterial];
    _currentPointNode = [SCNNode nodeWithGeometry:point];
    [_contentRoot addChildNode:_currentPointNode];
    [self updateCurrentPoint];
}

- (void)buildOscillatorCurve {
    QLSeries *xSeries = [self.result seriesNamed:@"x(t)"];
    QLSeries *pSeries = [self.result seriesNamed:@"p(t)"];
    if (!xSeries || !pSeries) return;
    NSInteger count = MIN(xSeries.yValues.count, pSeries.yValues.count);
    double tMax = self.result.tmax > 0 ? self.result.tmax : 1.0;
    double xMin = INFINITY, xMax = -INFINITY, pMin = INFINITY, pMax = -INFINITY;
    for (NSInteger i = 0; i < count; i++) {
        double x = xSeries.yValues[(NSUInteger)i].doubleValue;
        double p = pSeries.yValues[(NSUInteger)i].doubleValue;
        xMin = fmin(xMin, x); xMax = fmax(xMax, x);
        pMin = fmin(pMin, p); pMax = fmax(pMax, p);
    }
    double xSpan = fmax(1e-9, xMax - xMin);
    double pSpan = fmax(1e-9, pMax - pMin);
    NSMutableArray *path = [NSMutableArray arrayWithCapacity:(NSUInteger)count];
    for (NSInteger i = 0; i < count; i++) {
        double t = self.result.times[(NSUInteger)i].doubleValue;
        double x = xSeries.yValues[(NSUInteger)i].doubleValue;
        double p = pSeries.yValues[(NSUInteger)i].doubleValue;
        [path addObject:[NSValue valueWithSCNVector3:SCNVector3Make(
            (float)(-1.0 + 2.0 * t / tMax),
            (float)(-1.0 + 2.0 * (x - xMin) / xSpan),
            (float)(-1.0 + 2.0 * (p - pMin) / pSpan))]];
    }
    [_contentRoot addChildNode:[self tubeNodeWithPoints:path radius:0.009 color:NSColor.systemBlueColor]];

    NSArray *axisT = @[[NSValue valueWithSCNVector3:SCNVector3Make(-1.1, -1.1, -1.1)],
                       [NSValue valueWithSCNVector3:SCNVector3Make(1.1, -1.1, -1.1)]];
    NSArray *axisX = @[[NSValue valueWithSCNVector3:SCNVector3Make(-1.1, -1.1, -1.1)],
                       [NSValue valueWithSCNVector3:SCNVector3Make(-1.1, 1.1, -1.1)]];
    NSArray *axisP = @[[NSValue valueWithSCNVector3:SCNVector3Make(-1.1, -1.1, -1.1)],
                       [NSValue valueWithSCNVector3:SCNVector3Make(-1.1, -1.1, 1.1)]];
    NSColor *axisColor = [NSColor.labelColor colorWithAlphaComponent:0.75];
    [_contentRoot addChildNode:[self tubeNodeWithPoints:axisT radius:0.005 color:axisColor]];
    [_contentRoot addChildNode:[self tubeNodeWithPoints:axisX radius:0.005 color:axisColor]];
    [_contentRoot addChildNode:[self tubeNodeWithPoints:axisP radius:0.005 color:axisColor]];
    [_contentRoot addChildNode:[self textNode:@"t" at:SCNVector3Make(1.2, -1.1, -1.1) color:axisColor]];
    [_contentRoot addChildNode:[self textNode:@"x" at:SCNVector3Make(-1.1, 1.2, -1.1) color:axisColor]];
    [_contentRoot addChildNode:[self textNode:@"p" at:SCNVector3Make(-1.1, -1.1, 1.2) color:axisColor]];

    SCNSphere *point = [SCNSphere sphereWithRadius:0.045];
    point.segmentCount = 16;
    SCNMaterial *material = [SCNMaterial material];
    material.lightingModelName = SCNLightingModelConstant;
    material.diffuse.contents = NSColor.systemOrangeColor;
    material.emission.contents = NSColor.systemOrangeColor;
    point.materials = @[material];
    _currentPointNode = [SCNNode nodeWithGeometry:point];
    [_contentRoot addChildNode:_currentPointNode];
    [self updateCurrentPoint];
}

- (void)updateCurrentPoint {
    if (!_currentPointNode || !self.result) return;
    NSInteger index = self.frameIndex;
    if (self.result.isSpin) {
        QLSeries *sx = [self.result seriesNamed:@"Sx"];
        QLSeries *sy = [self.result seriesNamed:@"Sy"];
        QLSeries *sz = [self.result seriesNamed:@"Sz"];
        if (index < (NSInteger)sx.yValues.count && index < (NSInteger)sy.yValues.count && index < (NSInteger)sz.yValues.count) {
            _currentPointNode.position = SCNVector3Make(
                (float)sx.yValues[(NSUInteger)index].doubleValue,
                (float)sz.yValues[(NSUInteger)index].doubleValue,
                (float)sy.yValues[(NSUInteger)index].doubleValue);
        }
    } else if (self.result.isOscillator) {
        QLSeries *xSeries = [self.result seriesNamed:@"x(t)"];
        QLSeries *pSeries = [self.result seriesNamed:@"p(t)"];
        if (index < (NSInteger)xSeries.yValues.count && index < (NSInteger)pSeries.yValues.count) {
            double tMax = self.result.tmax > 0 ? self.result.tmax : 1.0;
            double t = self.result.times[(NSUInteger)index].doubleValue;
            double x = xSeries.yValues[(NSUInteger)index].doubleValue;
            double p = pSeries.yValues[(NSUInteger)index].doubleValue;
            double xMin = INFINITY, xMax = -INFINITY, pMin = INFINITY, pMax = -INFINITY;
            for (NSInteger i = 0; i < (NSInteger)xSeries.yValues.count; i++) {
                xMin = fmin(xMin, xSeries.yValues[(NSUInteger)i].doubleValue);
                xMax = fmax(xMax, xSeries.yValues[(NSUInteger)i].doubleValue);
            }
            for (NSInteger i = 0; i < (NSInteger)pSeries.yValues.count; i++) {
                pMin = fmin(pMin, pSeries.yValues[(NSUInteger)i].doubleValue);
                pMax = fmax(pMax, pSeries.yValues[(NSUInteger)i].doubleValue);
            }
            double xSpan = fmax(1e-9, xMax - xMin);
            double pSpan = fmax(1e-9, pMax - pMin);
            _currentPointNode.position = SCNVector3Make(
                (float)(-1.0 + 2.0 * t / tMax),
                (float)(-1.0 + 2.0 * (x - xMin) / xSpan),
                (float)(-1.0 + 2.0 * (p - pMin) / pSpan));
        }
    }
}

@end
