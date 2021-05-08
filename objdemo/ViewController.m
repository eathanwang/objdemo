//
//  ViewController.m
//  objdemo
//
//  Created by uc on 2017/12/10.
//  Copyright © 2017年 uc. All rights reserved.
//

#import "ViewController.h"
#import <CoreMotion/CoreMotion.h>

static const CGFloat kVelocityThreshold = 100.0f;
static const NSInteger kDisplayLinkCount = 100;
static const CGFloat kTranslationFactor = 10000.0;

@interface ViewController ()
@property (nonatomic, strong) CADisplayLink *displayLink;
@property (nonatomic, assign) CGPoint translation;
@property (nonatomic, assign) CGPoint translationDelta;
@property (nonatomic, assign) NSInteger total;
@property (nonatomic, assign) NSInteger count;

@property (nonatomic, assign) CGPoint longPressStartPoint;
@property (nonatomic, assign) CGPoint longPressOrigPoint;
@end

struct AttributeHandles
{
    GLint   aVertex;
    GLint   aNormal;
    GLint   aTexture;
};

struct UniformHandles
{
    GLuint  uProjectionMatrix;
    GLuint  uModelViewMatrix;
    GLuint  uNormalMatrix;
    
    GLint   uAmbient;
    GLint   uDiffuse;
    GLint   uSpecular;
    GLint   uExponent;
    
    GLint   uTexture;
    GLint   uMode;
};

@implementation ViewController
{
    struct AttributeHandles _attributes;
    struct UniformHandles   _uniforms;
    CMMotionManager *_motionManager;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    // Initialize Context & OpenGL ES
    self.context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
    
    // Setup View
    self.glkView = (GLKView *) self.view;
    self.glkView.context = self.context;
    self.glkView.opaque = YES;
    self.glkView.backgroundColor = [UIColor whiteColor];
    self.glkView.drawableColorFormat = GLKViewDrawableColorFormatRGBA8888;
    self.glkView.drawableDepthFormat = GLKViewDrawableDepthFormat16;
    
    // Initialize Class Objects
    self.shaderProcessor = [[ShaderProcessor alloc] init];
    
    // Setup OpenGL ES
    [self setupOpenGLES];
    
    self.displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(displayLinkRun)];
    self.displayLink.paused = YES;
    [self.displayLink addToRunLoop:[NSRunLoop currentRunLoop] forMode:NSRunLoopCommonModes];
    
    _motionManager = [CMMotionManager new];
}

- (void)setupOpenGLES
{
    [EAGLContext setCurrentContext:self.context];
    
    // Enable depth test
    glEnable(GL_DEPTH_TEST);
    
    // Projection Matrix
    CGRect screen = [[UIScreen mainScreen] bounds];
    float aspectRatio = fabsf((float)(screen.size.width / screen.size.height));
    _projectionMatrix = GLKMatrix4MakePerspective(GLKMathDegreesToRadians(45.0), aspectRatio, 0.1, 10.1);
    
    // ModelView Matrix
    _modelViewMatrix = GLKMatrix4Identity;
    
    // Initialize Model Pose
    self.transformations = [[Transformations alloc] initWithDepth:5.0f Scale:1.33f Translation:GLKVector2Make(0.0f, 0.0f) Rotation:GLKVector3Make(0.0f, 0.0f, 0.0f)];
    
    // Load Texture
    [self loadTexture:@"dog.jpg"];
    
    // Create the GLSL program
    _program = [self.shaderProcessor BuildProgram:ShaderV with:ShaderF];
    glUseProgram(_program);
    
    // Extract the attribute handles
    _attributes.aVertex = glGetAttribLocation(_program, "aVertex");
    _attributes.aNormal = glGetAttribLocation(_program, "aNormal");
    _attributes.aTexture = glGetAttribLocation(_program, "aTexture");
    
    // Extract the uniform handles
    _uniforms.uProjectionMatrix = glGetUniformLocation(_program, "uProjectionMatrix");
    _uniforms.uModelViewMatrix = glGetUniformLocation(_program, "uModelViewMatrix");
    _uniforms.uNormalMatrix = glGetUniformLocation(_program, "uNormalMatrix");
    _uniforms.uAmbient = glGetUniformLocation(_program, "uAmbient");
    _uniforms.uDiffuse = glGetUniformLocation(_program, "uDiffuse");
    _uniforms.uSpecular = glGetUniformLocation(_program, "uSpecular");
    _uniforms.uExponent = glGetUniformLocation(_program, "uExponent");
    _uniforms.uTexture = glGetUniformLocation(_program, "uTexture");
    _uniforms.uMode = glGetUniformLocation(_program, "uMode");
}

- (void)loadTexture:(NSString *)fileName
{
    NSDictionary *options = @{[NSNumber numberWithBool:YES] : GLKTextureLoaderOriginBottomLeft};
    
    NSError *error;
    NSString *path = [[NSBundle mainBundle] pathForResource:fileName ofType:nil];
    GLKTextureInfo *texture = [GLKTextureLoader textureWithContentsOfFile:path options:options error:&error];
    if (texture == nil) {
        NSLog(@"Error loading file: %@", [error localizedDescription]);
    }
    
    glBindTexture(GL_TEXTURE_2D, texture.name);
}

- (void)updateViewMatrices
{
    // ModelView Matrix
    _modelViewMatrix = [self.transformations getModelViewMatrix];
    
    // Normal Matrix
    // Transform object-space normals into eye-space
    _normalMatrix = GLKMatrix3Identity;
    bool isInvertible;
    _normalMatrix = GLKMatrix4GetMatrix3(GLKMatrix4InvertAndTranspose(_modelViewMatrix, &isInvertible));
}

# pragma mark - GLKView Delegate

- (void)glkView:(GLKView *)view drawInRect:(CGRect)rect
{
    [self.baseEffect prepareToDraw];
    
    double roll    = _motionManager.deviceMotion.attitude.roll;
    double pitch   = _motionManager.deviceMotion.attitude.pitch;
    double yaw     = _motionManager.deviceMotion.attitude.yaw;
    [_transformations updatePitch:pitch yaw:yaw];
    
    // Clear Buffers
    glClearColor(1.0, 1.0, 1.0, 1.0);
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    
    // Set View Matrices
    [self updateViewMatrices];
    glUniformMatrix4fv(_uniforms.uProjectionMatrix, 1, 0, _projectionMatrix.m);
    glUniformMatrix4fv(_uniforms.uModelViewMatrix, 1, 0, _modelViewMatrix.m);
    glUniformMatrix3fv(_uniforms.uNormalMatrix, 1, 0, _normalMatrix.m);
    
    // Attach Texture
    glUniform1i(_uniforms.uTexture, 0);
    
    // Set View Mode
    glUniform1i(_uniforms.uMode, (int)self.viewMode.selectedSegmentIndex);
    
    // Enable Attributes
    glEnableVertexAttribArray(_attributes.aVertex);
    glEnableVertexAttribArray(_attributes.aNormal);
    glEnableVertexAttribArray(_attributes.aTexture);
    
    // Load OBJ Data
    glVertexAttribPointer(_attributes.aVertex, 3, GL_FLOAT, GL_FALSE, 0, dogOBJVerts);
    glVertexAttribPointer(_attributes.aNormal, 3, GL_FLOAT, GL_FALSE, 0, dogOBJNormals);
    glVertexAttribPointer(_attributes.aTexture, 2, GL_FLOAT, GL_FALSE, 0, dogOBJTexCoords);
    
    // Load MTL Data
    for(int i=0; i<dogMTLNumMaterials; i++)
    {
        glUniform3f(_uniforms.uAmbient, dogMTLAmbient[i][0], dogMTLAmbient[i][1], dogMTLAmbient[i][2]);
        glUniform3f(_uniforms.uDiffuse, dogMTLDiffuse[i][0], dogMTLDiffuse[i][1], dogMTLDiffuse[i][2]);
        glUniform3f(_uniforms.uSpecular, dogMTLSpecular[i][0], dogMTLSpecular[i][1], dogMTLSpecular[i][2]);
        glUniform1f(_uniforms.uExponent, dogMTLExponent[i]);
        
        // Draw scene by material group
        glDrawArrays(GL_TRIANGLES, dogMTLFirst[i], dogMTLCount[i]);
    }
    
    // Disable Attributes
    glDisableVertexAttribArray(_attributes.aVertex);
    glDisableVertexAttribArray(_attributes.aNormal);
    glDisableVertexAttribArray(_attributes.aTexture);
}

# pragma mark - GLKViewController Delegate

- (void)glkViewControllerUpdate:(GLKViewController *)controller
{
}

// GESTURES

# pragma mark - Gestures

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    // Begin transformations
    self.displayLink.paused = YES;
    [self.transformations start];
}

- (IBAction)longPress:(UILongPressGestureRecognizer *)sender
{
    if (sender.state == UIGestureRecognizerStateBegan) {
        self.longPressStartPoint = [sender locationInView:sender.view];
    } else if (sender.state == UIGestureRecognizerStateChanged) {
        CGPoint curPoint = [sender locationInView:sender.view];
        CGPoint translation = CGPointMake(curPoint.x - self.longPressStartPoint.x, curPoint.y - self.longPressStartPoint.y);
        float x = translation.x/sender.view.frame.size.width;
        float y = translation.y/sender.view.frame.size.height;
        [self.transformations translate:GLKVector2Make(x, y) withMultiplier:2.0f];
    }
}

- (IBAction)pan:(UIPanGestureRecognizer *)sender
{
    
    CGFloat k = kTranslationFactor;
    if (sender.state == UIGestureRecognizerStateEnded && self.transformations.state == S_ROTATION) {
        //获取滑动路径向量t
        CGPoint t = [sender translationInView:sender.view];
        //获取手势结束时速度向量v
        CGPoint v = [sender velocityInView:sender.view];
        //设定一个阈值，只有速度向量v的x,y两个分量大于一定值的时候才启动惯性动画
        if (fabs(v.x) > kVelocityThreshold || fabs(v.y) > kVelocityThreshold) {
            //计算速度向量v的长度
            CGFloat d = sqrt(v.x * v.x + v.y * v.y);
            //计算惯性动画的初始速度向量nt：手势结束时速度越大，则该向量越大，这里用到一个因子kTranslationFactor，这个值经过测试得到，目前设置为10000
            CGPoint nt = CGPointMake(t.x / k * d, t.y / k * d);
            //缓存当前的滑动路径向量v，作为惯性动画期间的基数
            self.translation = t;
            //缓存惯性动画初始速度向量nt，在惯性动画期间需要逐渐递减
            self.translationDelta = nt;
            //设置惯性转动的执行次数
            self.total = kDisplayLinkCount;
            self.count = kDisplayLinkCount;
            //启动CADisplayLink
            self.displayLink.paused = NO;
        }
    }
    
    if((sender.numberOfTouches == 1 || sender.numberOfTouches == 2) &&
       ((self.transformations.state == S_NEW) || (self.transformations.state == S_ROTATION)))
    {
        const float m = GLKMathDegreesToRadians(0.5f);
        CGPoint rotation = [sender translationInView:sender.view];
        [self.transformations rotate:GLKVector3Make(rotation.x, rotation.y, 0.0f) withMultiplier:m];
    }
}

- (IBAction)pinch:(UIPinchGestureRecognizer *)sender
{
    // Pinch
    if((self.transformations.state == S_NEW) || (self.transformations.state == S_SCALE))
    {
        float scale = [sender scale];
        [self.transformations scale:scale];
    }
}

- (IBAction)rotation:(UIRotationGestureRecognizer *)sender
{
    // Rotation
    if((self.transformations.state == S_NEW) || (self.transformations.state == S_ROTATION))
    {
        float rotation = [sender rotation];
        [self.transformations rotate:GLKVector3Make(0.0f, 0.0f, rotation) withMultiplier:1.0f];
    }
}

//CADisplayLink回调方法
- (void)displayLinkRun
{
    //反复执行count次
    if (self.count > 0) {
        CGPoint t = self.translation;
        CGPoint nt = self.translationDelta;
        //逐渐递减速度
        t.x += (nt.x / self.total * self.count);
        t.y += (nt.y / self.total * self.count);
        //更新滑动向量基数，该值不断更新，则模型会不断旋转
        self.translation = t;
        const float m = GLKMathDegreesToRadians(0.5f);
        //用滑动向量于生成模型旋转矩阵所需的四元数
        [self.transformations rotate:GLKVector3Make(t.x, t.y, 0.0f) withMultiplier:m];
        self.count--;
    } else {
        self.displayLink.paused = YES;
    }
}

@end
