/*
     File: RippleViewController.m
 Abstract: View controller that handles camera, drawing, and touch events.
  Version: 1.0
 
 Disclaimer: IMPORTANT:  This Apple software is supplied to you by Apple
 Inc. ("Apple") in consideration of your agreement to the following
 terms, and your use, installation, modification or redistribution of
 this Apple software constitutes acceptance of these terms.  If you do
 not agree with these terms, please do not use, install, modify or
 redistribute this Apple software.
 
 In consideration of your agreement to abide by the following terms, and
 subject to these terms, Apple grants you a personal, non-exclusive
 license, under Apple's copyrights in this original Apple software (the
 "Apple Software"), to use, reproduce, modify and redistribute the Apple
 Software, with or without modifications, in source and/or binary forms;
 provided that if you redistribute the Apple Software in its entirety and
 without modifications, you must retain this notice and the following
 text and disclaimers in all such redistributions of the Apple Software.
 Neither the name, trademarks, service marks or logos of Apple Inc. may
 be used to endorse or promote products derived from the Apple Software
 without specific prior written permission from Apple.  Except as
 expressly stated in this notice, no other rights or licenses, express or
 implied, are granted by Apple herein, including but not limited to any
 patent rights that may be infringed by your derivative works or by other
 works in which the Apple Software may be incorporated.
 
 The Apple Software is provided by Apple on an "AS IS" basis.  APPLE
 MAKES NO WARRANTIES, EXPRESS OR IMPLIED, INCLUDING WITHOUT LIMITATION
 THE IMPLIED WARRANTIES OF NON-INFRINGEMENT, MERCHANTABILITY AND FITNESS
 FOR A PARTICULAR PURPOSE, REGARDING THE APPLE SOFTWARE OR ITS USE AND
 OPERATION ALONE OR IN COMBINATION WITH YOUR PRODUCTS.
 
 IN NO EVENT SHALL APPLE BE LIABLE FOR ANY SPECIAL, INDIRECT, INCIDENTAL
 OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 INTERRUPTION) ARISING IN ANY WAY OUT OF THE USE, REPRODUCTION,
 MODIFICATION AND/OR DISTRIBUTION OF THE APPLE SOFTWARE, HOWEVER CAUSED
 AND WHETHER UNDER THEORY OF CONTRACT, TORT (INCLUDING NEGLIGENCE),
 STRICT LIABILITY OR OTHERWISE, EVEN IF APPLE HAS BEEN ADVISED OF THE
 POSSIBILITY OF SUCH DAMAGE.
 
 Copyright (C) 2013 Apple Inc. All Rights Reserved.
 
 */

#import <CoreVideo/CVOpenGLESTextureCache.h>
#import "RippleViewController.h"
#import "RippleModel.h"

// Uniform index.
enum
{
    UNIFORM_TEXTURE_0,
    UNIFORM_TEXTURE_1,
    NUM_UNIFORMS
};
GLint uniforms[NUM_UNIFORMS];

// Attribute index.
enum
{
    ATTRIB_VERTEX,
    ATTRIB_TEXCOORD,
    NUM_ATTRIBUTES
};

@interface RippleViewController () {
    GLuint _program1, _program2;
    
	GLuint _framebufferName;

    GLuint _positionVBO;
    GLuint _texcoordVBO;
    GLuint _indexVBO;
    
    CGFloat _screenWidth;
    CGFloat _screenHeight;
    size_t _textureWidth;
    size_t _textureHeight;
    
    EAGLContext *_context;
    RippleModel *_ripple;
}

- (void)setupBuffers;
- (void)useProgram:(GLuint)program;
- (void)setupGL;
- (void)tearDownGL;

- (BOOL)loadShadersNamed: (NSString *)name program:(GLuint *)program;
- (BOOL)compileShader:(GLuint *)shader type:(GLenum)type file:(NSString *)file;
- (BOOL)linkProgram:(GLuint)prog;
@end

@implementation RippleViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    _context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];

    if (!_context) {
        NSLog(@"Failed to create ES context");
    }
    
    GLKView *view = (GLKView *)self.view;
    view.context = _context;
    self.preferredFramesPerSecond = 60;
    
    _screenWidth = [UIScreen mainScreen].bounds.size.width;
    _screenHeight = [UIScreen mainScreen].bounds.size.height;
    view.contentScaleFactor = [UIScreen mainScreen].scale;
    
	[self setupGL];
	
	if (_ripple == nil)
	{
		unsigned int meshFactor;
		
		if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
		{
			// meshFactor controls the ending ripple mesh size.
			// For example mesh width = screenWidth / meshFactor.
			// It's chosen based on both screen resolution and device size.
			meshFactor = 8;
		}
		else
		{
			meshFactor = 4;
		}
		
		_ripple = [[RippleModel alloc] initWithScreenWidth:_screenWidth
											  screenHeight:_screenHeight
											 meshFactor:meshFactor
											   touchRadius:5
											  textureWidth:_textureWidth
											 textureHeight:_textureHeight];
		
		[self setupBuffers];
	}
}

- (void)viewDidUnload
{    
    [super viewDidUnload];
	
    [self tearDownGL];
    
    if ([EAGLContext currentContext] == _context) {
        [EAGLContext setCurrentContext:nil];
    }
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Release any cached data, images, etc. that aren't in use.
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    // Camera image orientation on screen is fixed 
    // with respect to the physical camera orientation.
    
    if (interfaceOrientation == UIInterfaceOrientationPortrait)
        return YES;
    else
        return NO;
}

- (void)setupBuffers
{
    glGenBuffers(1, &_indexVBO);
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, _indexVBO);
    glBufferData(GL_ELEMENT_ARRAY_BUFFER, [_ripple getIndexSize], [_ripple getIndices], GL_STATIC_DRAW);
    
    glGenBuffers(1, &_positionVBO);
    glBindBuffer(GL_ARRAY_BUFFER, _positionVBO);
    glBufferData(GL_ARRAY_BUFFER, [_ripple getVertexSize], [_ripple getVertices], GL_STATIC_DRAW);
    
    glEnableVertexAttribArray(ATTRIB_VERTEX);
    glVertexAttribPointer(ATTRIB_VERTEX, 2, GL_FLOAT, GL_FALSE, 2*sizeof(GLfloat), 0);

    glGenBuffers(1, &_texcoordVBO);
    glBindBuffer(GL_ARRAY_BUFFER, _texcoordVBO);
    glBufferData(GL_ARRAY_BUFFER, [_ripple getVertexSize], [_ripple getTexCoords], GL_DYNAMIC_DRAW);
    
    glEnableVertexAttribArray(ATTRIB_TEXCOORD);
    glVertexAttribPointer(ATTRIB_TEXCOORD, 2, GL_FLOAT, GL_FALSE, 2*sizeof(GLfloat), 0);
}

- (void)useProgram:(GLuint)program
{
	glUseProgram(program);
	
    glUniform1i(uniforms[UNIFORM_TEXTURE_0], 0);
    glUniform1i(uniforms[UNIFORM_TEXTURE_1], 1);
}

- (void)setupGL
{
	[EAGLContext setCurrentContext:_context];
    
    [self loadShadersNamed:@"Shader1" program:&(_program1)];
    [self loadShadersNamed:@"Shader2" program:&(_program2)];
	
	//create the framebuffer
	glGenFramebuffers(1, &_framebufferName);
	glBindFramebuffer(GL_FRAMEBUFFER, _framebufferName);
	
	//create the GLKTextureInfo object
	NSError *error;
	GLKTextureInfo *texture1 = [GLKTextureLoader textureWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"Background.png" ofType:nil]
																   options:nil
																	 error:&error]; assert(!error);
	
	GLKTextureInfo *texture2 = [GLKTextureLoader textureWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"Liquid.png" ofType:nil]
																   options:nil
																	 error:&error]; assert(!error);
	
	//bind the texture to texture unit 0
	glActiveTexture(GL_TEXTURE0 + 0);
	glBindTexture(texture1.target, texture1.name);
	glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
	glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
	
	//bind the texture to texture unit 1
	glActiveTexture(GL_TEXTURE0 + 1);
	glBindTexture(texture2.target, texture2.name);
	glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
	glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
	
	_textureWidth = texture1.width;
	_textureHeight = texture1.height;
}

- (void)tearDownGL
{
    [EAGLContext setCurrentContext:_context];
    
    glDeleteBuffers(1, &_positionVBO);
    glDeleteBuffers(1, &_texcoordVBO);
    glDeleteBuffers(1, &_indexVBO);
    
    if (_program1) {
        glDeleteProgram(_program1);
        _program1 = 0;
    }
	
	if (_program2) {
        glDeleteProgram(_program2);
        _program2 = 0;
    }
}

#pragma mark - GLKView and GLKViewController delegate methods

- (void)update
{
    if (_ripple)
    {
        [_ripple runSimulation];

        // no need to rebind GL_ARRAY_BUFFER to _texcoordVBO since it should be still be bound from setupBuffers
        glBufferData(GL_ARRAY_BUFFER, [_ripple getVertexSize], [_ripple getTexCoords], GL_DYNAMIC_DRAW);
    }
}

- (void)glkView:(GLKView *)view drawInRect:(CGRect)rect
{
    glClear(GL_COLOR_BUFFER_BIT);
    
	[self useProgram:_program2];

    if (_ripple)
    {
        glDrawElements(GL_TRIANGLE_STRIP, [_ripple getIndexCount], GL_UNSIGNED_SHORT, 0);
    }
	
	/*
	typedef struct {
		GLfloat p[2];
		GLfloat tc[2];
	} vertex;
	
	vertex vetices[] =
	{
		{{-.5,-.5},	{1,0}},
		{{-.5,.5},	{0,0}},
		{{.5,.5},	{0,1}},
		{{.5,-.5},	{1,1}}
	};
	
	GLubyte indices[] = {0, 1, 2, 0, 2, 3};
	
	glBindBuffer(GL_ARRAY_BUFFER, 0);
	glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, 0);
	
    glVertexAttribPointer(ATTRIB_VERTEX, 2, GL_FLOAT, GL_FALSE, sizeof(vertex), (char *)vetices);
    glVertexAttribPointer(ATTRIB_TEXCOORD, 2, GL_FLOAT, GL_FALSE, sizeof(vertex), (char *)vetices+offsetof(vertex, tc));
	
	glDrawElements(GL_TRIANGLES, 6, GL_UNSIGNED_BYTE, indices);
	*/
}

#pragma mark - Touch handling methods

- (void)myTouch:(NSSet *)touches withEvent:(UIEvent *)event
{
    for (UITouch *touch in touches) 
    {
        CGPoint location = [touch locationInView:touch.view]; 
        [_ripple initiateRippleAtLocation:location]; 
    }
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    [self myTouch:touches withEvent:event];
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
    [self myTouch:touches withEvent:event];
}

#pragma mark - OpenGL ES 2 shader compilation

- (BOOL)loadShadersNamed: (NSString *)name program:(GLuint *)program
{
    GLuint vertShader, fragShader;
    NSString *vertShaderPathname, *fragShaderPathname;
    
    // Create shader program.
    *program = glCreateProgram();
    
    // Create and compile vertex shader.
    vertShaderPathname = [[NSBundle mainBundle] pathForResource:name ofType:@"vsh"];
    if (![self compileShader:&vertShader type:GL_VERTEX_SHADER file:vertShaderPathname]) {
        NSLog(@"Failed to compile vertex shader");
        return NO;
    }
    
    // Create and compile fragment shader.
    fragShaderPathname = [[NSBundle mainBundle] pathForResource:name ofType:@"fsh"];
    if (![self compileShader:&fragShader type:GL_FRAGMENT_SHADER file:fragShaderPathname]) {
        NSLog(@"Failed to compile fragment shader");
        return NO;
    }
    
    // Attach vertex shader to program.
    glAttachShader(*program, vertShader);
    
    // Attach fragment shader to program.
    glAttachShader(*program, fragShader);
    
    // Bind attribute locations.
    // This needs to be done prior to linking.
    glBindAttribLocation(*program, ATTRIB_VERTEX, "position");
    glBindAttribLocation(*program, ATTRIB_TEXCOORD, "texCoord");
    
    // Link program.
    if (![self linkProgram:*program]) {
        NSLog(@"Failed to link program: %d", *program);
        
        if (vertShader) {
            glDeleteShader(vertShader);
            vertShader = 0;
        }
        if (fragShader) {
            glDeleteShader(fragShader);
            fragShader = 0;
        }
        if (*program) {
            glDeleteProgram(*program);
            *program = 0;
        }
        
        return NO;
    }
    
    // Get uniform locations.
    uniforms[UNIFORM_TEXTURE_0] = glGetUniformLocation(*program, "texture0");
    uniforms[UNIFORM_TEXTURE_1] = glGetUniformLocation(*program, "texture1");
    
    // Release vertex and fragment shaders.
    if (vertShader) {
        glDetachShader(*program, vertShader);
        glDeleteShader(vertShader);
    }
    if (fragShader) {
        glDetachShader(*program, fragShader);
        glDeleteShader(fragShader);
    }
    
    return YES;
}

- (BOOL)compileShader:(GLuint *)shader type:(GLenum)type file:(NSString *)file
{
    GLint status;
    const GLchar *source;
    
    source = (GLchar *)[[NSString stringWithContentsOfFile:file encoding:NSUTF8StringEncoding error:nil] UTF8String];
    if (!source) {
        NSLog(@"Failed to load vertex shader");
        return NO;
    }
    
    *shader = glCreateShader(type);
    glShaderSource(*shader, 1, &source, NULL);
    glCompileShader(*shader);
    
#if defined(DEBUG)
    GLint logLength;
    glGetShaderiv(*shader, GL_INFO_LOG_LENGTH, &logLength);
    if (logLength > 0) {
        GLchar *log = (GLchar *)malloc(logLength);
        glGetShaderInfoLog(*shader, logLength, &logLength, log);
        NSLog(@"Shader compile log:\n%s", log);
        free(log);
    }
#endif
    
    glGetShaderiv(*shader, GL_COMPILE_STATUS, &status);
    if (status == 0) {
        glDeleteShader(*shader);
        return NO;
    }
    
    return YES;
}

- (BOOL)linkProgram:(GLuint)prog
{
    GLint status;
    glLinkProgram(prog);
    
#if defined(DEBUG)
    GLint logLength;
    glGetProgramiv(prog, GL_INFO_LOG_LENGTH, &logLength);
    if (logLength > 0) {
        GLchar *log = (GLchar *)malloc(logLength);
        glGetProgramInfoLog(prog, logLength, &logLength, log);
        NSLog(@"Program link log:\n%s", log);
        free(log);
    }
#endif
    
    glGetProgramiv(prog, GL_LINK_STATUS, &status);
    if (status == 0) {
        return NO;
    }
    
    return YES;
}

@end
