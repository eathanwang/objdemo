//
//  Transformations.m
//  MTL
//
//  Created by RRC on 9/28/13.
//  Copyright (c) 2013 RRC. All rights reserved.
//

#import "Transformations.h"
#include <glm/glm.hpp>
#include <glm/gtc/matrix_transform.hpp>

@interface Transformations ()
{
    // Vectors
    GLKVector3      _right;
    GLKVector3      _up;
    GLKVector3      _front;
    GLKVector3      _worldUp;
    
    // Depth
    float           _depth;
    
    // Scale
    float           _scaleStart;
    float           _scaleEnd;
    
    // Translation
    GLKVector2      _translationStart;
    GLKVector2      _translationEnd;
    
    // Rotation
    GLKVector3      _rotationStart;
    GLKQuaternion   _rotationEnd;
    
    GLKMatrix4      _viewMatrix;
}

@end

@implementation Transformations

- (id)initWithDepth:(float)z Scale:(float)s Translation:(GLKVector2)t Rotation:(GLKVector3)r
{
    if(self = [super init])
    {
        // Vectors
        _right = GLKVector3Make(1.0f, 0.0f, 0.0f);
        _up = GLKVector3Make(0.0f, 1.0f, 0.0f);
        _front = GLKVector3Make(0.0f, 0.0f, 1.0f);
        _up = GLKVector3Make(0.0f, 1.0f, 0.0f);
        _worldUp = GLKVector3Make(0.0f, 1.0f, 0.0f);
        
        // Depth
        _depth = z;
        
        // Scale
        _scaleEnd = s;
        
        // Translation
        _translationEnd = t;
        
        // Rotation
        r.x = GLKMathDegreesToRadians(r.x);
        r.y = GLKMathDegreesToRadians(r.y);
        r.z = GLKMathDegreesToRadians(r.z);
        _rotationEnd = GLKQuaternionIdentity;
        _rotationEnd = GLKQuaternionMultiply(GLKQuaternionMakeWithAngleAndVector3Axis(-r.x, _right), _rotationEnd);
        _rotationEnd = GLKQuaternionMultiply(GLKQuaternionMakeWithAngleAndVector3Axis(-r.y, _up), _rotationEnd);
        _rotationEnd = GLKQuaternionMultiply(GLKQuaternionMakeWithAngleAndVector3Axis(-r.z, _front), _rotationEnd);
    }
    
    return self;
}

- (void)start
{
    self.state = S_NEW;
    _scaleStart = _scaleEnd;
    _translationStart = GLKVector2Make(0.0f, 0.0f);
    _rotationStart = GLKVector3Make(0.0f, 0.0f, 0.0f);
}

- (void)scale:(float)s
{
    self.state = S_SCALE;
    
    _scaleEnd = s * _scaleStart;
}

- (void)translate:(GLKVector2)t withMultiplier:(float)m
{
    self.state = S_TRANSLATION;
    
    t = GLKVector2MultiplyScalar(t, m);
    
    float dx = _translationEnd.x + (t.x-_translationStart.x);
    float dy = _translationEnd.y - (t.y-_translationStart.y);
    
    _translationEnd = GLKVector2Make(dx, dy);
    _translationStart = GLKVector2Make(t.x, t.y);
}

- (void)rotate:(GLKVector3)r withMultiplier:(float)m
{
    self.state = S_ROTATION;
    
    float dx = r.x - _rotationStart.x;
    float dy = r.y - _rotationStart.y;
    float dz = r.z - _rotationStart.z;
    
    _rotationStart = GLKVector3Make(r.x, r.y, r.z);
    _rotationEnd = GLKQuaternionMultiply(GLKQuaternionMakeWithAngleAndVector3Axis(dx*m, _up), _rotationEnd);
    _rotationEnd = GLKQuaternionMultiply(GLKQuaternionMakeWithAngleAndVector3Axis(dy*m, _right), _rotationEnd);
    _rotationEnd = GLKQuaternionMultiply(GLKQuaternionMakeWithAngleAndVector3Axis(-dz, _front), _rotationEnd);
}

- (void)updatePitch:(float)pitch yaw:(float)yaw
{
    pitch = M_PI / 3;
    yaw = M_PI / 2;
//    _front.x = cos(pitch) * 0;
//    _front.y = sin(pitch);
//    _front.z = cos(pitch) * 1;
//    _front = GLKVector3Normalize(_front);
//    _right = GLKVector3CrossProduct(_front, _worldUp);
//    _up = GLKVector3CrossProduct(_right, _front);
    glm::vec3 front = glm::vec3(cos(pitch) * 0, sin(pitch), cos(pitch) * 1);
    glm::vec3 worldUp = glm::vec3(_worldUp.x, _worldUp.y, _worldUp.z);
    glm::vec3 newFront = glm::normalize(front);
    glm::vec3 newRight = glm::normalize(glm::cross(newFront, worldUp));
    glm::vec3 newUp = glm::normalize(glm::cross(newRight, newFront));
    _viewMatrix = GLKMatrix4MakeLookAt(0, 0, _depth, 0, 0, 0, newUp.x, newUp.y, newUp.z);
//    NSLog(@"aaa");
}

- (glm::vec3)GLKVec3ToGlmVec3:(GLKVector3)glkVec3
{
    return glm::vec3(glkVec3.x, glkVec3.y, glkVec3.z);
}

- (GLKVector3)glmVec3ToGLKVec3:(glm::vec3)glmVec3
{
    return GLKVector3Make(glmVec3.x, glmVec3.y, glmVec3.z);
}

- (GLKMatrix4)getModelViewMatrix
{
    GLKMatrix4 modelMatrix = GLKMatrix4Identity;
    GLKMatrix4 quaternionMatrix = GLKMatrix4MakeWithQuaternion(_rotationEnd);
    modelMatrix = GLKMatrix4Translate(modelMatrix, _translationEnd.x, _translationEnd.y, 0);
    modelMatrix = GLKMatrix4Multiply(modelMatrix, quaternionMatrix);
    modelMatrix = GLKMatrix4Scale(modelMatrix, _scaleEnd, _scaleEnd, _scaleEnd);
    
    GLKMatrix4 modelViewMatrix = GLKMatrix4Multiply(_viewMatrix, modelMatrix);
    return modelViewMatrix;
}

@end
