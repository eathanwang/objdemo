//
//  ViewController.h
//  objdemo
//
//  Created by uc on 2017/12/10.
//  Copyright © 2017年 uc. All rights reserved.
//

#import <GLKit/GLKit.h>

// Models
#import "dogOBJ.h"
#import "dogMTL.h"

// Transformations
#import "Transformations.h"

// Shaders
#import "ShaderProcessor.h"
#define STRINGIFY(A) #A
#include "Shader.vsh"
#include "Shader.fsh"

@interface ViewController : GLKViewController <GLKViewDelegate, GLKViewControllerDelegate>
{
    // Render
    GLuint  _program;
    GLuint  _texture;
    
    // View
    GLKMatrix4  _projectionMatrix;
    GLKMatrix4  _modelViewMatrix;
    GLKMatrix3  _normalMatrix;
}

// Class Objects
@property (strong, nonatomic) ShaderProcessor* shaderProcessor;
@property (strong, nonatomic) Transformations* transformations;

// View
@property (strong, nonatomic) EAGLContext* context;
@property (strong, nonatomic) GLKView* glkView;
@property (strong, nonatomic) GLKBaseEffect *baseEffect;

// UI Controls
@property (weak, nonatomic) IBOutlet UISlider* rotateX;
@property (weak, nonatomic) IBOutlet UISlider* rotateY;
@property (weak, nonatomic) IBOutlet UISlider* rotateZ;
@property (weak, nonatomic) IBOutlet UISegmentedControl* viewMode;

@end

