//
//  OSOpenGLESViewController.m
//  OpenGLES_Shader_003
//
//  Created by xu jie on 16/8/23.
//  Copyright © 2016年 xujie. All rights reserved.
//

#import "OSOpenGLESViewController.h"
#import <OpenGLES/ES2/gl.h>
#import <OpenGLES/ES2/glext.h>
#import <OpenGLES/ES1/gl.h>
#import <OpenGLES/ES1/glext.h>
#import "OSSphere.h"
#import <CoreMotion/CoreMotion.h>

/**
 *  定义一下关于球体模型的常量
 */
#define OSMAX_OVERTURE 95.0
#define OSMIN_OVERTURE 25.0
#define OSDEFAULT_OVERTURE 85.0

#define OSROLL_CORRECTION ES_PI/2.0
#define OSFramesPerSecond 60  // 帧率
#define OSSphereSliceNum 300
#define OSSphereRadius 1.0   // 球体模型半径
#define OSSphereScale 300
#define OSVIEW_CORNER  85.0  // 视角


#import "OSShaderManager.h"


@interface OSOpenGLESViewController () {
    GLuint _vertexArray;
    
    // 顶点和纹理坐标属性标识
    GLuint _vertexBuffer;
    GLuint _textureCoordBuffer;
    GLuint _indexBuffer;
    
    // 着色器变量标识
    GLuint _textureBufferY;
    GLuint _textureBufferUV;
    GLuint _modelViewProjectionMatrixIndex;
    GLuint _texCoordIndex;
    
    
    GLuint _texture1;
    GLuint _texture2;
    
  
    CVOpenGLESTextureRef _lumaTexture;
    CVOpenGLESTextureRef _chromaTexture;
    CVOpenGLESTextureCacheRef _videoTextureCache;
    
    // 顶点数据，纹理坐标数组
    GLfloat *_vertices  ;
    GLfloat *_texCoords  ;
    GLushort *_indices  ;
    GLint  _numIndices;
    
    GLKMatrix4 _projectionMatrix;
    GLKMatrix4 _modelViewMatrix;
    GLKMatrix4 _modelViewProjectionMatrix;
    
   
    
}
@property(nonatomic,strong)OSShaderManager *shaderManager;
@property(nonatomic,strong)EAGLContext *eagContext;
@property (strong, nonatomic) CMMotionManager *motionManager; // 传感器管理类
@property (assign, nonatomic) CGFloat fingerRotationX;
@property (assign, nonatomic) CGFloat fingerRotationY;
@property (strong, nonatomic) CMAttitude *referenceAttitude;
@property (strong, nonatomic) NSMutableArray *currentTouches;

@end

@implementation OSOpenGLESViewController

- (instancetype)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil{
    if (self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil]){
        self.vedioType = OSPanorama;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];

 
    
    [self initUI];
    // 第一步初始化
    [self setup];
    // 第二步, 导入顶点坐标和纹理坐标
    
    [self loadVertexAndTexCoord];
    // 第三步. 初始化投影矩阵 和模型矩阵
    
    if (self.vedioType == OSPanorama){
         [self initModelViewProjectMatrix];
        
    }
   
}

-(void)initUI{
    
    self.currentTouches = [NSMutableArray array];
    
}
- (void)setIsVR:(BOOL)isVR{
    _isVR = isVR;
    if (self.vedioType == OSPanorama){
        if (isVR){
            
            [self startMotionManager];
            return;
        }
        [self stopMotionManager];
        [self initModelViewProjectMatrix];
    }
   
}

-(void)glkView:(GLKView *)view drawInRect:(CGRect)rect{
    glClearColor(0, 0, 0, 1);
    glClear(GL_COLOR_BUFFER_BIT);
    int scale = 2;
    if ([UIScreen mainScreen].bounds.size.width > 500){
        scale = 3;
    }
    
    
    if (_isVR){
        glViewport(0, 0, self.view.bounds.size.width*scale/2.0, self.view.bounds.size.height*scale);
        glDrawElements(GL_TRIANGLES, _numIndices, GL_UNSIGNED_SHORT, 0);
        glViewport(self.view.bounds.size.width*scale/2.0, 0, self.view.bounds.size.width*scale/2.0, self.view.bounds.size.height*scale);
        glDrawElements(GL_TRIANGLES, _numIndices, GL_UNSIGNED_SHORT, 0);
    }else{
        glViewport(0, 0, self.view.bounds.size.width*scale, self.view.bounds.size.height*scale);
        glDrawElements(GL_TRIANGLES, _numIndices, GL_UNSIGNED_SHORT, 0);
    }
   
    
}

-(void)loadVertexAndTexCoord{
 
    int numVertices = 0; // 顶点的个数
    int strideNum = 2; // 数据的步伐数 比如顶点数据为(1,1)，数组就为2
    
    
    // 动态生成球体数据,用的是指针的方式，占用的是堆区的内存，数据加载到GPU中去，要释放掉内存，不释放也没关系，因为我们只调用一次这个方法，不会产生内存溢出的问题,但是会增加内存。
    if (self.vedioType == OSPanorama){
        _numIndices =  generateSphere(OSSphereSliceNum, OSSphereRadius, &_vertices, &_texCoords, &_indices, &numVertices);
        strideNum = 3;
    }else{
           _numIndices = generateSquare(&_vertices, &_indices, &_texCoords, &numVertices);
                strideNum = 2;
        
    }
   

    glGenBuffers(1, &_indexBuffer);
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, _indexBuffer);
    glBufferData(GL_ELEMENT_ARRAY_BUFFER, _numIndices*sizeof(GLushort), _indices, GL_STATIC_DRAW);
    
 
    // 加载顶点坐标
    glGenBuffers(1, &_vertexBuffer);
    glBindBuffer(GL_ARRAY_BUFFER, _vertexBuffer);
  
    glBufferData(GL_ARRAY_BUFFER, numVertices*strideNum*sizeof(GLfloat), _vertices, GL_STATIC_DRAW);
  
    glEnableVertexAttribArray(GLKVertexAttribPosition);
    glVertexAttribPointer(GLKVertexAttribPosition, strideNum, GL_FLOAT, GL_FALSE, strideNum*sizeof(GLfloat), NULL);
    
    //加载纹理坐标
    glGenBuffers(1, &_textureCoordBuffer);
    glBindBuffer(GL_ARRAY_BUFFER, _textureCoordBuffer);
    glBufferData(GL_ARRAY_BUFFER, sizeof(GLfloat)*2*numVertices, _texCoords, GL_DYNAMIC_DRAW);
   
    glEnableVertexAttribArray(GLKVertexAttribTexCoord0);
    glVertexAttribPointer(GLKVertexAttribTexCoord0, 2, GL_FLOAT, GL_FALSE, 2*sizeof(GLfloat), NULL);
    
    // 释放内存
    free(_vertices);
    free(_indices);
    free(_texCoords);
    
    
}
-(void)initModelViewProjectMatrix{
    // 创建投影矩阵
    float aspect = fabs(self.view.bounds.size.width / self.view.bounds.size.height);
    _projectionMatrix = GLKMatrix4MakePerspective(GLKMathDegreesToRadians(OSVIEW_CORNER), aspect, 0.1f, 400.0f);
    _projectionMatrix = GLKMatrix4Rotate(_projectionMatrix, ES_PI, 1.0f, 0.0f, 0.0f);
    
    // 创建模型矩阵
    _modelViewMatrix = GLKMatrix4Identity;
    float scale = OSSphereScale;
    _modelViewMatrix = GLKMatrix4Scale(_modelViewMatrix, scale, scale, scale);
    
    // 最终传入到GLSL中去的矩阵
    _modelViewProjectionMatrix = GLKMatrix4Multiply(_projectionMatrix, _modelViewMatrix);
    glUniformMatrix4fv(_modelViewProjectionMatrixIndex, 1, GL_FALSE, _modelViewProjectionMatrix.m);
}


-(void)startMotionManager{
    self.motionManager = [[CMMotionManager alloc]init];
    self.motionManager.deviceMotionUpdateInterval = 1.0 / 60.0;
    self.motionManager.gyroUpdateInterval = 1.0f / 60;
    self.motionManager.showsDeviceMovementDisplay = YES;
    [self.motionManager startDeviceMotionUpdatesUsingReferenceFrame:CMAttitudeReferenceFrameXArbitraryCorrectedZVertical];
     self.referenceAttitude = nil;
    [self.motionManager startGyroUpdatesToQueue: [[NSOperationQueue alloc]init] withHandler:^(CMGyroData * _Nullable gyroData, NSError * _Nullable error) {
        if(self.isVR) {
        
          [self calculateModelViewProjectMatrixWithDeviceMotion:self.motionManager.deviceMotion];
        }
        
    }];
    self.referenceAttitude = self.motionManager.deviceMotion.attitude;
}

-(void)stopMotionManager{
    [self.motionManager stopDeviceMotionUpdates];
    self.referenceAttitude = nil;
    
}
-(void)calculateModelViewProjectMatrixWithDeviceMotion:(CMDeviceMotion*)deviceMotion{
   
    _modelViewMatrix = GLKMatrix4Identity;
    float scale = OSSphereScale;
    _modelViewMatrix = GLKMatrix4Scale(_modelViewMatrix, scale, scale, scale);
        if (deviceMotion != nil) {
            CMAttitude *attitude = deviceMotion.attitude;
            
            if (self.referenceAttitude != nil) {
                [attitude multiplyByInverseOfAttitude:self.referenceAttitude];
                
            } else {
                self.referenceAttitude = deviceMotion.attitude;
            }
            
            float cRoll = attitude.roll;
            float cPitch = attitude.pitch;
            
            _modelViewMatrix = GLKMatrix4RotateX(_modelViewMatrix, -cRoll);
            _modelViewMatrix = GLKMatrix4RotateY(_modelViewMatrix, -cPitch*3);
    
            _modelViewProjectionMatrix = GLKMatrix4Multiply(_projectionMatrix, _modelViewMatrix);
            // 下边这个方法必须在主线程中完成.
            dispatch_async(dispatch_get_main_queue(), ^{
                 glUniformMatrix4fv(_modelViewProjectionMatrixIndex, 1, GL_FALSE, _modelViewProjectionMatrix.m);
            });
            
    
        }}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    if(self.isVR || self.vedioType == OSNormal) return;
    for (UITouch *touch in touches) {
        [_currentTouches addObject:touch];
    }
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event {
    if(self.isVR || self.vedioType == OSNormal ) return;
    UITouch *touch = [touches anyObject];
    float distX = [touch locationInView:touch.view].x - [touch previousLocationInView:touch.view].x;
    float distY = [touch locationInView:touch.view].y - [touch previousLocationInView:touch.view].y;
    distX *= -0.005;
    distY *= -0.005;
    self.fingerRotationX += distY *  OSVIEW_CORNER / 100;
    self.fingerRotationY -= distX *  OSVIEW_CORNER / 100;
    _modelViewMatrix = GLKMatrix4Identity;
    float scale = OSSphereScale;
    _modelViewMatrix = GLKMatrix4Scale(_modelViewMatrix, scale, scale, scale);
    _modelViewMatrix = GLKMatrix4RotateX(_modelViewMatrix, self.fingerRotationX);
    _modelViewMatrix = GLKMatrix4RotateY(_modelViewMatrix, self.fingerRotationY);
    _modelViewProjectionMatrix = GLKMatrix4Multiply(_projectionMatrix, _modelViewMatrix);
    glUniformMatrix4fv(_modelViewProjectionMatrixIndex, 1, GL_FALSE, _modelViewProjectionMatrix.m);
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
    if (self.isVR || self.vedioType == OSNormal) return;
      for (UITouch *touch in touches) {
        [self.currentTouches removeObject:touch];
    }
}
- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event {
    for (UITouch *touch in touches) {
        [self.currentTouches removeObject:touch];
    }
}




-(void)loadPixbuffer:(CVPixelBufferRef)pixelBuffer{
    
    
    
    if (!_videoTextureCache) {
        NSLog(@"No video texture cache");
        return;
    }
    CFTypeRef colorAttachments = CVBufferGetAttachment(pixelBuffer, kCVImageBufferYCbCrMatrixKey, NULL);
    
    if (colorAttachments == kCVImageBufferYCbCrMatrix_ITU_R_601_4) {
       
    }
    else {
      
    }

    CGFloat width = CVPixelBufferGetWidth(pixelBuffer);
    CGFloat height = CVPixelBufferGetHeight(pixelBuffer);

    [self cleanUpTextures];
     CVReturn err;

    glActiveTexture(GL_TEXTURE0);
    
    err = CVOpenGLESTextureCacheCreateTextureFromImage(kCFAllocatorDefault,
                                                       _videoTextureCache,
                                                       pixelBuffer,
                                                       NULL,
                                                       GL_TEXTURE_2D,
                                                       GL_RED_EXT,
                                                       width,
                                                       height,
                                                       GL_RED_EXT,
                                                       GL_UNSIGNED_BYTE,
                                                       0,
                                                       &_lumaTexture);
    if (err) {
        NSLog(@"Error at CVOpenGLESTextureCacheCreateTextureFromImage %d", err);
        
    }
    
    glBindTexture(CVOpenGLESTextureGetTarget(_lumaTexture), CVOpenGLESTextureGetName(_lumaTexture));
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    
    // UV-plane.
    glActiveTexture(GL_TEXTURE1);
    err = CVOpenGLESTextureCacheCreateTextureFromImage(kCFAllocatorDefault,
                                                       _videoTextureCache,
                                                       pixelBuffer,
                                                       NULL,
                                                       GL_TEXTURE_2D,
                                                       GL_RG_EXT,
                                                       width /2,
                                                       height /2,
                                                       GL_RG_EXT,
                                                       GL_UNSIGNED_BYTE,
                                                       1,
                                                       &_chromaTexture);
    if (err) {
        NSLog(@"Error at CVOpenGLESTextureCacheCreateTextureFromImage %d", err);
    }
    
    
    glBindTexture(CVOpenGLESTextureGetTarget(_chromaTexture), CVOpenGLESTextureGetName(_chromaTexture));
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    
   

    
    
}

- (void)cleanUpTextures
{
    if (_lumaTexture) {
        CFRelease(_lumaTexture);
        _lumaTexture = NULL;
    }
    
    if (_chromaTexture) {
        CFRelease(_chromaTexture);
        _chromaTexture = NULL;
    }
    
    CVOpenGLESTextureCacheFlush(_videoTextureCache, 0);
}




-(void)setup{
    self.eagContext = [[EAGLContext alloc]initWithAPI:kEAGLRenderingAPIOpenGLES2];
    [EAGLContext setCurrentContext:self.eagContext];
    GLKView *view = (GLKView*)self.view;
    view.drawableDepthFormat = GLKViewDrawableDepthFormat24;
    view.context = self.eagContext;
    self.preferredFramesPerSecond = OSFramesPerSecond;
    
    // 编译加载程序
    if (self.vedioType == OSPanorama){
        [self createShaderProgramVertexShaderName:@"ShaderPanorama" FragmentShaderName:@"ShaderPanorama"];
    }else{
        [self createShaderProgramVertexShaderName:@"ShaderNormal" FragmentShaderName:@"ShaderNormal"];
    }
    
    
    // 一定要放在使用程序之后，不然程序不知道你下面的操作是干神马滴！！！
    
    glUniform1i(_textureBufferY, 0); // 0 代表GL_TEXTURE0
    glUniform1i(_textureBufferUV, 1); // 1 代表GL_TEXTURE1
  
    
    if (!_videoTextureCache) {
        CVReturn err = CVOpenGLESTextureCacheCreate(kCFAllocatorDefault, NULL, self.eagContext, NULL, &_videoTextureCache);
        if (err != noErr) {
            NSLog(@"Error at CVOpenGLESTextureCacheCreate %d", err);
            return;
        }
    }
    
}
/**
 *  创建编译shader程序
 *
 *  @param vshName 顶点着色器文件名称
 *  @param fshName 片段着色器文件名称
 */
-(void)createShaderProgramVertexShaderName:(NSString*)vshName FragmentShaderName:(NSString*)fshName{
    self.shaderManager = [[OSShaderManager alloc]init];
    // 编译连个shader 文件
    GLuint vertexShader,fragmentShader;
    NSURL *vertexShaderPath = [[NSBundle mainBundle]URLForResource:vshName withExtension:@"vsh"];
    NSURL *fragmentShaderPath = [[NSBundle mainBundle]URLForResource:fshName withExtension:@"fsh"];
    if (![self.shaderManager compileShader:&vertexShader type:GL_VERTEX_SHADER URL:vertexShaderPath]||![self.shaderManager compileShader:&fragmentShader type:GL_FRAGMENT_SHADER URL:fragmentShaderPath]){
        return ;
    }
    
    // 注意获取绑定属性要在连接程序之前 location 随便你写
    [self.shaderManager bindAttribLocation:GLKVertexAttribPosition andAttribName:"position"];
    [self.shaderManager bindAttribLocation:GLKVertexAttribTexCoord0 andAttribName:"texCoord0"];
    
    
    // 将编译好的两个对象和着色器程序进行连接
    if(![self.shaderManager linkProgram]){
        [self.shaderManager deleteShader:&vertexShader];
        [self.shaderManager deleteShader:&fragmentShader];
    }
    _textureBufferY = [self.shaderManager getUniformLocation:"sam2DY"];
    _textureBufferUV = [self.shaderManager getUniformLocation:"sam2DUV"];
    _modelViewProjectionMatrixIndex = [self.shaderManager getUniformLocation:"modelViewProjectionMatrix"];
    
    [self.shaderManager detachAndDeleteShader:&vertexShader];
    [self.shaderManager detachAndDeleteShader:&fragmentShader];
    
    // 启用着色器
    [self.shaderManager useProgram];
}

/*下面是显示像素相关的方法*/
-(void)displayPixelBuffer:(CVPixelBufferRef)pixelBuffer{
    if (pixelBuffer != NULL){
        [self loadPixbuffer:pixelBuffer];
    }
   
   
}







@end
