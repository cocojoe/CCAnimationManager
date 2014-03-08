/*
 * SpriteBuilder: http://www.spritebuilder.org
 *
 * Copyright (c) 2012 Zynga Inc.
 * Copyright (c) 2013 Apportable Inc.
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 */

#import "CCBAnimationManager.h"
#import "CCBSequence.h"
#import "CCBSequenceProperty.h"
#import "CCBReader.h"
#import "CCBKeyframe.h"
#import "OALSimpleAudio.h"
#import <objc/runtime.h>

#import "CCDirector_Private.h"
#import "CCBReader_Private.h"
#import "CCActionManager.h"

// Unique Manager ID
static NSInteger ccbAnimationManagerID = 0;

@implementation CCBAnimationManager

@synthesize sequences;
@synthesize autoPlaySequenceId;
@synthesize rootNode;
@synthesize rootContainerSize;
@synthesize owner;
@synthesize delegate;
@synthesize lastCompletedSequenceName;

- (id) init
{
    self = [super init];
    if (!self) return NULL;
    
    animationManagerId = ccbAnimationManagerID;
    ccbAnimationManagerID++;
    
    sequences = [[NSMutableArray alloc] init];
    nodeSequences = [[NSMutableDictionary alloc] init];
    baseValues = [[NSMutableDictionary alloc] init];
    
    // Scheduler
    _scheduler = [[CCDirector sharedDirector] scheduler];
    [_scheduler scheduleTarget:self];
    
    // Current Sequence Actions
    _currentActions = [[NSMutableArray alloc] init];
    _playbackSpeed  = 1.0f;
    [self setPaused:NO];
    
    return self;
}

-(NSInteger)priority
{
	return 0;
}

-(void) setPaused:(bool)paused {
    [_scheduler setPaused:paused target:self];
    _paused = paused;
}


- (CGSize) containerSize:(CCNode*)node
{
    if (node) return node.contentSize;
    else return rootContainerSize;
}

- (void) addNode:(CCNode*)node andSequences:(NSDictionary*)seq
{
    NSValue* nodePtr = [NSValue valueWithPointer:(__bridge const void *)(node)];
    [nodeSequences setObject:seq forKey:nodePtr];
}

- (void) moveAnimationsFromNode:(CCNode*)fromNode toNode:(CCNode*)toNode
{
    NSValue* fromNodePtr = [NSValue valueWithPointer:(__bridge const void *)(fromNode)];
    NSValue* toNodePtr = [NSValue valueWithPointer:(__bridge const void *)(toNode)];
    
    // Move base values
    id baseValue = [baseValues objectForKey:fromNodePtr];
    if (baseValue)
    {
        [baseValues setObject:baseValue forKey:toNodePtr];
        [baseValues removeObjectForKey:fromNodePtr];
    }
    
    // Move keyframes
    NSDictionary* seqs = [nodeSequences objectForKey:fromNodePtr];
    if (seqs)
    {
        [nodeSequences setObject:seqs forKey:toNodePtr];
        [nodeSequences removeObjectForKey:fromNodePtr];
    }
}

- (void) setBaseValue:(id)value forNode:(CCNode*)node propertyName:(NSString*)propName
{
    NSValue* nodePtr = [NSValue valueWithPointer:(__bridge const void *)(node)];
    
    NSMutableDictionary* props = [baseValues objectForKey:nodePtr];
    if (!props)
    {
        props = [NSMutableDictionary dictionary];
        [baseValues setObject:props forKey:nodePtr];
    }
    
    [props setObject:value forKey:propName];
}

- (id) baseValueForNode:(CCNode*) node propertyName:(NSString*) propName
{
    NSValue* nodePtr = [NSValue valueWithPointer:(__bridge const void *)(node)];
    
    NSMutableDictionary* props = [baseValues objectForKey:nodePtr];
    return [props objectForKey:propName];
}

- (int) sequenceIdForSequenceNamed:(NSString*)name
{
    for (CCBSequence* seq in sequences)
    {
        if ([seq.name isEqualToString:name])
        {
            return seq.sequenceId;
        }
    }
    return -1;
}

- (CCBSequence*) sequenceFromSequenceId:(int)seqId
{
    for (CCBSequence* seq in sequences)
    {
        if (seq.sequenceId == seqId) return seq;
    }
    return NULL;
}

- (CCActionInterval*) actionFromKeyframe0:(CCBKeyframe*)kf0 andKeyframe1:(CCBKeyframe*)kf1 propertyName:(NSString*)name node:(CCNode*)node
{
    float duration = kf1.time - kf0.time;
    
    if ([name isEqualToString:@"rotation"])
    {
        return [CCActionRotateTo actionWithDuration:duration angle:[kf1.value floatValue]];
    }
    else if ([name isEqualToString:@"rotationalSkewX"])
    {
        return [CCActionRotateTo actionWithDuration:duration angleX:[kf1.value floatValue]];
    }
    else if ([name isEqualToString:@"rotationalSkewY"])
    {
        return [CCActionRotateTo actionWithDuration:duration angleY:[kf1.value floatValue]];
    }
    else if ([name isEqualToString:@"opacity"])
    {
        return [CCActionFadeTo actionWithDuration:duration opacity:[kf1.value intValue]];
    }
    else if ([name isEqualToString:@"color"])
    {
        CCColor* color = kf1.value;
        return [CCActionTintTo actionWithDuration:duration color:color];
    }
    else if ([name isEqualToString:@"visible"])
    {
        if ([kf1.value boolValue])
        {
            return [CCActionSequence actionOne:[CCActionDelay actionWithDuration:duration] two:[CCActionShow action]];
        }
        else
        {
            return [CCActionSequence actionOne:[CCActionDelay actionWithDuration:duration] two:[CCActionHide action]];
        }
    }
    else if ([name isEqualToString:@"spriteFrame"])
    {
        return [CCActionSequence actionOne:[CCActionDelay actionWithDuration:duration] two:[CCActionSpriteFrame actionWithSpriteFrame:kf1.value]];
    }
    else if ([name isEqualToString:@"position"])
    {
        // Get position type
        //int type = [[[self baseValueForNode:node propertyName:name] objectAtIndex:2] intValue];
        
        id value = kf1.value;
        
        // Get relative position
        float x = [[value objectAtIndex:0] floatValue];
        float y = [[value objectAtIndex:1] floatValue];
        
        //CGSize containerSize = [self containerSize:node.parent];
        
        //CGPoint absPos = [node absolutePositionFromRelative:ccp(x,y) type:type parentSize:containerSize propertyName:name];
        
        return [CCActionMoveTo actionWithDuration:duration position:ccp(x,y)];
    }
    else if ([name isEqualToString:@"scale"])
    {
        // Get position type
        //int type = [[[self baseValueForNode:node propertyName:name] objectAtIndex:2] intValue];
        
        id value = kf1.value;
        
        // Get relative scale
        float x = [[value objectAtIndex:0] floatValue];
        float y = [[value objectAtIndex:1] floatValue];
        
        /*
         if (type == kCCBScaleTypeMultiplyResolution)
         {
         float resolutionScale = [node resolutionScale];
         x *= resolutionScale;
         y *= resolutionScale;
         }*/
        
        return [CCActionScaleTo actionWithDuration:duration scaleX:x scaleY:y];
    }
    else if ([name isEqualToString:@"skew"])
    {
        id value = kf1.value;
        
        float x = [[value objectAtIndex:0] floatValue];
        float y = [[value objectAtIndex:1] floatValue];
        
        return [CCActionSkewTo actionWithDuration:duration skewX:x skewY:y];
    }
    else
    {
        NSLog(@"CCBReader: Failed to create animation for property: %@", name);
    }
    return NULL;
}

- (void) setAnimatedProperty:(NSString*)name forNode:(CCNode*)node toValue:(id)value tweenDuration:(float) tweenDuration
{
    if (tweenDuration > 0)
    {
        // Create a fake keyframe to generate the action from
        CCBKeyframe* kf1 = [[CCBKeyframe alloc] init];
        kf1.value = value;
        kf1.time = tweenDuration;
        kf1.easingType = kCCBKeyframeEasingLinear;
        
        // Animate @toto Add to current actions (needs tested)
        CCActionInterval* tweenAction = [self actionFromKeyframe0:NULL andKeyframe1:kf1 propertyName:name node:node];
        tweenAction.tag = animationManagerId;
        [tweenAction startWithTarget:node];
        [_currentActions addObject:tweenAction];
    }
    else
    {
        // Just set the value
        
        if ([name isEqualToString:@"position"])
        {
            // Get position type
            //int type = [[[self baseValueForNode:node propertyName:name] objectAtIndex:2] intValue];
            
            // Get relative position
            float x = [[value objectAtIndex:0] floatValue];
            float y = [[value objectAtIndex:1] floatValue];
#ifdef __CC_PLATFORM_IOS
            [node setValue:[NSValue valueWithCGPoint:ccp(x,y)] forKey:name];
#elif defined (__CC_PLATFORM_MAC)
            [node setValue:[NSValue valueWithPoint:ccp(x,y)] forKey:name];
#endif
            
            //[node setRelativePosition:ccp(x,y) type:type parentSize:[self containerSize:node.parent] propertyName:name];
        }
        else if ([name isEqualToString:@"scale"])
        {
            // Get scale type
            //int type = [[[self baseValueForNode:node propertyName:name] objectAtIndex:2] intValue];
            
            // Get relative scale
            float x = [[value objectAtIndex:0] floatValue];
            float y = [[value objectAtIndex:1] floatValue];
            
            [node setValue:[NSNumber numberWithFloat:x] forKey:[name stringByAppendingString:@"X"]];
            [node setValue:[NSNumber numberWithFloat:y] forKey:[name stringByAppendingString:@"Y"]];
            
            //[node setRelativeScaleX:x Y:y type:type propertyName:name];
        }
        else if ([name isEqualToString:@"skew"])
        {
            node.skewX = [[value objectAtIndex:0] floatValue];
            node.skewY = [[value objectAtIndex:1] floatValue];
        }
        else
        {
            [node setValue:value forKey:name];
        }
    }
}

- (void) setKeyFrameForNode:(CCNode*)node sequenceProperty:(CCBSequenceProperty*)seqProp tweenDuration:(float)tweenDuration keyFrame:(int)kf
{
    NSArray* keyframes = [seqProp keyframes];
    
    if ([keyframes count] == 0) {
        // No Animation, Set Base Value
        id baseValue = [self baseValueForNode:node propertyName:seqProp.name];
        NSAssert1(baseValue, @"No baseValue found for property (%@)", seqProp.name);
        [self setAnimatedProperty:seqProp.name forNode:node toValue:baseValue tweenDuration:tweenDuration];
        
    } else {
        
        // Use Specified KeyFrame
        CCBKeyframe* keyframe = [keyframes objectAtIndex:kf];
        [self setAnimatedProperty:seqProp.name forNode:node toValue:keyframe.value tweenDuration:tweenDuration];
    }
}

- (CCActionInterval*) easeAction:(CCActionInterval*) action easingType:(int)easingType easingOpt:(float) easingOpt
{
    if ([action isKindOfClass:[CCActionSequence class]]) return action;
    
    if (easingType == kCCBKeyframeEasingLinear)
    {
        return action;
    }
    else if (easingType == kCCBKeyframeEasingInstant)
    {
        return [CCActionEaseInstant actionWithAction:action];
    }
    else if (easingType == kCCBKeyframeEasingCubicIn)
    {
        return [CCActionEaseIn actionWithAction:action rate:easingOpt];
    }
    else if (easingType == kCCBKeyframeEasingCubicOut)
    {
        return [CCActionEaseOut actionWithAction:action rate:easingOpt];
    }
    else if (easingType == kCCBKeyframeEasingCubicInOut)
    {
        return [CCActionEaseInOut actionWithAction:action rate:easingOpt];
    }
    else if (easingType == kCCBKeyframeEasingBackIn)
    {
        return [CCActionEaseBackIn actionWithAction:action];
    }
    else if (easingType == kCCBKeyframeEasingBackOut)
    {
        return [CCActionEaseBackOut actionWithAction:action];
    }
    else if (easingType == kCCBKeyframeEasingBackInOut)
    {
        return [CCActionEaseBackInOut actionWithAction:action];
    }
    else if (easingType == kCCBKeyframeEasingBounceIn)
    {
        return [CCActionEaseBounceIn actionWithAction:action];
    }
    else if (easingType == kCCBKeyframeEasingBounceOut)
    {
        return [CCActionEaseBounceOut actionWithAction:action];
    }
    else if (easingType == kCCBKeyframeEasingBounceInOut)
    {
        return [CCActionEaseBounceInOut actionWithAction:action];
    }
    else if (easingType == kCCBKeyframeEasingElasticIn)
    {
        return [CCActionEaseElasticIn actionWithAction:action period:easingOpt];
    }
    else if (easingType == kCCBKeyframeEasingElasticOut)
    {
        return [CCActionEaseElasticOut actionWithAction:action period:easingOpt];
    }
    else if (easingType == kCCBKeyframeEasingElasticInOut)
    {
        return [CCActionEaseElasticInOut actionWithAction:action period:easingOpt];
    }
    else
    {
        NSLog(@"CCBReader: Unkown easing type %d", easingType);
        return action;
    }
}

- (void) runActionsForNode:(CCNode*)node sequenceProperty:(CCBSequenceProperty*)seqProp tweenDuration:(float)tweenDuration startKeyFrame:(int)startFrame
{
    
    // Grab Key Frames / Count
    NSArray* keyframes = [seqProp keyframes];
    int numKeyframes   = (int)keyframes.count;
    
    // Nothing to do - No Keyframes
    if(numKeyframes<1)
        return;
    
    // Action Sequence Builder
    NSMutableArray* actions = [NSMutableArray array];
    int nextFrame           = startFrame+1;
    
    if(nextFrame==numKeyframes)
        return;
    
    // KeyFrames to build action sequence
    CCBKeyframe* kf0 = [keyframes objectAtIndex:startFrame];
    CCBKeyframe* kf1 = [keyframes objectAtIndex:nextFrame];
    
    float timeFirst = kf0.time + tweenDuration;
    
    // Handle Tween
    if (timeFirst > 0 && startFrame==0) {
        [actions addObject:[CCActionDelay actionWithDuration:timeFirst]];
    }
    
    //CCLOG(@"startFrame: %d -> nextFrame: %d, KeyFrames: %d",startFrame,nextFrame,numKeyframes);
    
    // Create Sequence
    CCActionInterval* action = [self actionFromKeyframe0:kf0 andKeyframe1:kf1 propertyName:seqProp.name node:node];
    
    // Apply Easing Modifier (Optional)
    if (action) {
        action = [self easeAction:action easingType:kf0.easingType easingOpt:kf0.easingOpt];
        [actions addObject:action];
    }
    
    CCActionCallBlock* nextKeyFrameBlock = [CCActionCallBlock actionWithBlock:^{
        [self runActionsForNode:node sequenceProperty:seqProp tweenDuration:0 startKeyFrame:nextFrame];
    }];
    
    [actions addObject:nextKeyFrameBlock];
    
    
    // Create Sequence Added to Manager Sequence Array
    CCActionSequence* seq = [CCActionSequence actionWithArray:actions];
    seq.tag = animationManagerId;
    [seq startWithTarget:node];
    [_currentActions addObject:seq];
    
    //CCLOG(@"Actions Added: %d",(int)[actions count]);
}

- (id) actionForCallbackChannel:(CCBSequenceProperty*) channel
{
    float lastKeyframeTime = 0;
    
    NSMutableArray* actions = [NSMutableArray array];
    
    for (CCBKeyframe* keyframe in channel.keyframes)
    {
        float timeSinceLastKeyframe = keyframe.time - lastKeyframeTime;
        lastKeyframeTime = keyframe.time;
        if (timeSinceLastKeyframe > 0)
        {
            [actions addObject:[CCActionDelay actionWithDuration:timeSinceLastKeyframe]];
        }
        
        NSString* selectorName = [keyframe.value objectAtIndex:0];
        int selectorTarget = [[keyframe.value objectAtIndex:1] intValue];
        
        // Callback through obj-c
        id target = NULL;
        if (selectorTarget == kCCBTargetTypeDocumentRoot) target = self.rootNode;
        else if (selectorTarget == kCCBTargetTypeOwner) target = owner;
        
        SEL selector = NSSelectorFromString(selectorName);
        
        if (target && selector)
        {
            [actions addObject:[CCActionCallFunc actionWithTarget:target selector:selector]];
        }
    }
    
    if (!actions.count) return NULL;
    
    return [CCActionSequence actionWithArray:actions];
}

- (id) actionForSoundChannel:(CCBSequenceProperty*) channel
{
    float lastKeyframeTime = 0;
    
    NSMutableArray* actions = [NSMutableArray array];
    
    for (CCBKeyframe* keyframe in channel.keyframes)
    {
        float timeSinceLastKeyframe = keyframe.time - lastKeyframeTime;
        lastKeyframeTime = keyframe.time;
        if (timeSinceLastKeyframe > 0)
        {
            [actions addObject:[CCActionDelay actionWithDuration:timeSinceLastKeyframe]];
        }
        
        NSString* soundFile = [keyframe.value objectAtIndex:0];
        float pitch = [[keyframe.value objectAtIndex:1] floatValue];
        float pan = [[keyframe.value objectAtIndex:2] floatValue];
        float gain = [[keyframe.value objectAtIndex:3] floatValue];
        
        [actions addObject:[CCActionSoundEffect actionWithSoundFile:soundFile pitch:pitch pan:pan gain:gain]];
    }
    
    if (!actions.count) return NULL;
    
    return [CCActionSequence actionWithArray:actions];
}

- (void) runAnimationsForSequenceId:(int)seqId tweenDuration:(float) tweenDuration
{
    NSAssert(seqId != -1, @"Sequence id %d couldn't be found",seqId);
    
    [self clearNodeActions];
    
    // Contains all Sequence Propertys / Keyframe
    for (NSValue* nodePtr in nodeSequences)
    {
        CCNode* node = [nodePtr pointerValue];
        
        NSDictionary* seqs = [nodeSequences objectForKey:nodePtr];
        NSDictionary* seqNodeProps = [seqs objectForKey:[NSNumber numberWithInt:seqId]];
        
        NSMutableSet* seqNodePropNames = [NSMutableSet set];
        
        // Reset nodes that have sequence node properties, build first action sequence.
        for (NSString* propName in seqNodeProps)
        {
            CCBSequenceProperty* seqProp = [seqNodeProps objectForKey:propName];
            [seqNodePropNames addObject:propName];
            
            // Reset Node State to First KeyFrame
            [self setKeyFrameForNode:node sequenceProperty:seqProp tweenDuration:tweenDuration keyFrame:0];
            
            // Build First Key Frame Sequence
            [self runActionsForNode:node sequenceProperty:seqProp tweenDuration:tweenDuration startKeyFrame:0];
        }
        
        // Reset the nodes that may have been changed by other timelines
        NSDictionary* nodeBaseValues = [baseValues objectForKey:nodePtr];
        for (NSString* propName in nodeBaseValues)
        {
            if (![seqNodePropNames containsObject:propName])
            {
                id value = [nodeBaseValues objectForKey:propName];
                
                if (value)
                {
                    [self setAnimatedProperty:propName forNode:node toValue:value tweenDuration:tweenDuration];
                }
            }
        }
    }
    
    // End of Sequence Callback
    CCBSequence* seq = [self sequenceFromSequenceId:seqId];
    CCActionSequence* completeAction = [CCActionSequence
                                        actionOne:[CCActionDelay actionWithDuration:seq.duration+tweenDuration]
                                        two:[CCActionCallFunc actionWithTarget:self selector:@selector(sequenceCompleted)]];
    completeAction.tag = animationManagerId;
    
    [completeAction startWithTarget:rootNode];
    [_currentActions addObject:completeAction];
    
    // Playback callbacks and sounds
    if (seq.callbackChannel) {
        // Build sound actions for channel
        CCAction* action = [self actionForCallbackChannel:seq.callbackChannel];
        if (action) {
            action.tag = animationManagerId;
        }
    }
    
    if (seq.soundChannel) {
        // Build sound actions for channel
        CCAction* action = [self actionForSoundChannel:seq.soundChannel];
        if (action) {
            action.tag = animationManagerId;
        }
    }
    
    // Set the running scene
    runningSequence = [self sequenceFromSequenceId:seqId];
}

- (void) runAnimationsForSequenceNamed:(NSString*)name tweenDuration:(float)tweenDuration
{
    int seqId = [self sequenceIdForSequenceNamed:name];
    [self runAnimationsForSequenceId:seqId tweenDuration:tweenDuration];
}

- (void) runAnimationsForSequenceNamed:(NSString*)name
{
    [self runAnimationsForSequenceNamed:name tweenDuration:0];
}

- (void) sequenceCompleted
{
    // Save last completed sequence
    if (lastCompletedSequenceName != runningSequence.name)
    {
        lastCompletedSequenceName = [runningSequence.name copy];
    }
    
    // Play next sequence
    int nextSeqId = runningSequence.chainedSequenceId;
    runningSequence = NULL;
    
    // Callbacks
    [delegate completedAnimationSequenceNamed:lastCompletedSequenceName];
    if (block) block(self);
    
    // Run next sequence if callbacks did not start a new sequence
    if (runningSequence == NULL && nextSeqId != -1)
    {
        [self runAnimationsForSequenceId:nextSeqId tweenDuration:0];
    }
}

- (NSString*) runningSequenceName
{
    return runningSequence.name;
}

-(void) setCompletedAnimationCallbackBlock:(void(^)(id sender))b
{
    block = [b copy];
}

/*
 - (void) setCallFunc:(CCCallBlockN *)callFunc forJSCallbackNamed:(NSString *)callbackNamed
 {
 [keyframeCallFuncs setObject:callFunc forKey:callbackNamed];
 }
 */

- (void) dealloc
{
    self.rootNode = NULL;
    
}

- (void) debug
{
    CCLOG(@"baseValues: %@", baseValues);
    CCLOG(@"nodeSequences: %@", nodeSequences);
}

- (void)jumpToKeyFrame:(int)keyFrame {
    
    // Contains all Sequence Propertys / Keyframe
    for (NSValue* nodePtr in nodeSequences)
    {
        CCNode* node = [nodePtr pointerValue];
        
        // Stop actions associated with this animation manager
        [self clearNodeActions];
        
        NSDictionary* seqs = [nodeSequences objectForKey:nodePtr];
        NSDictionary* seqNodeProps = [seqs objectForKey:[NSNumber numberWithInt:autoPlaySequenceId]];
        
        // Reset nodes that have sequence node properties, and run actions on them
        for (NSString* propName in seqNodeProps)
        {
            CCBSequenceProperty* seqProp = [seqNodeProps objectForKey:propName];
            //CCLOG(@"%@",seqProp);
            
            [self setKeyFrameForNode:node sequenceProperty:seqProp tweenDuration:0 keyFrame:keyFrame];
        }
        
    }
}

- (void)jumpToTime:(float)time {
    
    // Contains all Sequence Propertys / Keyframe
    for (NSValue* nodePtr in nodeSequences)
    {
        CCNode* node = [nodePtr pointerValue];
        
        // Stop actions associated with this animation manager
        [self clearNodeActions];
        
        NSDictionary* seqs = [nodeSequences objectForKey:nodePtr];
        NSDictionary* seqNodeProps = [seqs objectForKey:[NSNumber numberWithInt:autoPlaySequenceId]];
        
        // Reset nodes that have sequence node properties, and run actions on them
        for (NSString* propName in seqNodeProps)
        {
            CCBSequenceProperty* seqProp = [seqNodeProps objectForKey:propName];
            NSMutableArray* keyFrames    = [self findFrames:time sequenceProperty:seqProp];
            
            // No KeyFrames Found
            if([keyFrames count]==0) {
                continue;
            }
            
            // Time Matches Exact KeyFrame (Set Node From Key Frame)
            if([keyFrames count]==1) {
                [self setKeyFrameForNode:node sequenceProperty:seqProp tweenDuration:0 keyFrame:[[keyFrames objectAtIndex:0] intValue]];
            } else {
                // Set Initial State First Key Frame
                [self setKeyFrameForNode:node sequenceProperty:seqProp tweenDuration:0 keyFrame:[[keyFrames objectAtIndex:0] intValue]];
                
                CCBKeyframe* currentKeyFrame = [seqProp.keyframes objectAtIndex:[[keyFrames objectAtIndex:0] unsignedIntegerValue]];
                
                float timeFoward = time - currentKeyFrame.time;
                
                // Fast-Forward to Time Point
                CCLOG(@"Time Fast Foward: %f", timeFoward);
                
                // Create Action Sequence
                CCActionSequence* animSequence = [self createActionForNode:node
                                                          sequenceProperty:seqProp
                                                             beginKeyFrame:[[keyFrames objectAtIndex:0] intValue]
                                                               endKeyFrame:[[keyFrames objectAtIndex:1] intValue]];
                
                // Fast Forward
                [animSequence startWithTarget:node];
                [animSequence update:timeFoward];
                [animSequence stop];
                
            }
        }
        
    }
}

// Needs tested with emtpy keyframes etc
-(NSMutableArray*) findFrames:(float)time sequenceProperty:(CCBSequenceProperty*) seqProp{
    NSMutableArray* result = [[NSMutableArray alloc] init];
    
    CCBKeyframe* startKeyFrame = [seqProp.keyframes objectAtIndex:0];
    CCBKeyframe* endKeyFrame   = [seqProp.keyframes objectAtIndex:0];
    
    NSUInteger frameCount = [seqProp.keyframes count];
    
    // Find KeyFrames
    for (int i = 0; i < frameCount; i++) {
        CCBKeyframe* currentKey = [seqProp.keyframes objectAtIndex:i];
        
        if(currentKey.time==time) {
            [result addObject:[NSNumber numberWithUnsignedInteger:[seqProp.keyframes indexOfObject:currentKey]]];
            goto endFindFrames;
        } else if (currentKey.time>time) {
            endKeyFrame = currentKey;
            // Add KeyFrames
            [result addObject:[NSNumber numberWithUnsignedInteger:[seqProp.keyframes indexOfObject:startKeyFrame]]];
            [result addObject:[NSNumber numberWithUnsignedInteger:[seqProp.keyframes indexOfObject:endKeyFrame]]];
            goto endFindFrames;
        }
        
        startKeyFrame = [seqProp.keyframes objectAtIndex:i];
    }
    
endFindFrames:
    
    return result;
}

- (CCActionSequence*)createActionForNode:(CCNode*)node sequenceProperty:(CCBSequenceProperty*)seqProp beginKeyFrame:(int)beginKeyFrame endKeyFrame:(int)endKeyFrame
{
    NSArray* keyframes = [seqProp keyframes];
    
    // Build Animation Actions
    NSMutableArray* actions = [[NSMutableArray alloc] init];
    
    CCBKeyframe* startKF = [keyframes objectAtIndex:beginKeyFrame];
    CCBKeyframe* endKF   = [keyframes objectAtIndex:endKeyFrame];
    
    CCActionInterval* action = [self actionFromKeyframe0:startKF andKeyframe1:endKF propertyName:seqProp.name node:node];
    
    if (action) {
        // @todo Apply Easing (Review This)
        action = [self easeAction:action easingType:startKF.easingType easingOpt:endKF.easingOpt];
        [actions addObject:action];
    }
    
    
    CCActionSequence* seq = [CCActionSequence actionWithArray:actions];
    seq.tag = animationManagerId;
    return seq;
}

-(void) update:(CCTime)delta {
    
    NSArray *actionsCopy = [_currentActions copy];
    
    for(CCAction *action in actionsCopy) {
        [action step:delta*_playbackSpeed];
        
        if([action isDone]) {
            [_currentActions removeObject:action];
        }
    }
    
    //CCLOG(@"Actions: %d",(int)[_currentActions count]);
}

-(void) clearNodeActions {
    
    for(CCAction *action in _currentActions) {
        [action stop];
    }
    
    [_currentActions removeAllObjects];
}


-(void) reset {
    [self jumpToKeyFrame:0];
}

@end