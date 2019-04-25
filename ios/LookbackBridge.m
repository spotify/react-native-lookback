//
//  LookbackBridge.m
//  RNLookback
//
//  Created by Sam J Thorne on 10/01/2019.
//  Copyright © 2019 Spotify AB. All rights reserved.
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at

//     http://www.apache.org/licenses/LICENSE-2.0

//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.

#import "LookbackBridge.h"
#import <Foundation/Foundation.h>

@implementation LookbackBridge

static NSString * const LookbackStatusContext;
static NSString * const LookbackBridgeAfterRecording = @"afterRecording";
static NSString * const LookbackBridgeTimeout = @"timeout";
static NSString * const LookbackBridgeCameraEnabled = @"cameraEnabled";
static NSString * const LookbackBridgeMicrophoneEnabled = @"microphoneEnabled";
static NSString * const LookbackBridgeConsoleRecordingEnabled = @"consoleRecordingEnabled";
static NSString * const LookbackBridgeShowCameraPreviewWhileRecording = @"showCameraPreviewWhileRecording";
static NSString * const LookbackBridgeFramerateLimit = @"framerateLimit";
static NSString * const LookbackBridgeUserIdentifier = @"userIdentifier";
static NSString * const LookbackBridgeUserFullName = @"userFullName";
static NSString * const LookbackBridgeProjectId = @"projectId";
static NSString * const LookbackBridgeStudyId = @"studyId";
static NSString * const LookbackBridgeAllowSavingPreviewsAsDrafts = @"allowSavingPreviewsAsDrafts";
static NSString * const LookbackBridgeAllowResumeRecordingFromPreview = @"allowResumeRecordingFromPreview";
static NSString * const LookbackBridgeAutomaticallyRecordViewControllerNames = @"automaticallyRecordViewControllerNames";
static NSString * const LookbackBridgeUpdateLookbackSetting = @"updateLookbackSetting";
static NSString * const LookbackBridgeOnStartedUpload = @"onStartedUpload";

/**
 Registration methods for React Native
 */
RCT_EXPORT_PRE_REGISTERED_MODULE()
RCT_EXTERN void RCTRegisterModule(Class);

/**
 Tell React Native to use the Main Queue for Lookback

 @return main queue
 */
- (dispatch_queue_t)methodQueue
{
    return dispatch_get_main_queue();
}

/**
 Tell React Native to use the Main Queue for setup

 @return YES
 */
+ (BOOL)requiresMainQueueSetup
{
    return YES;
}

/**
 Predefined RN method to pass a list of events to be able to register for in RN

 @return NSArray of strings of event names Spotify Bridge will dispatch
 */
- (NSArray<NSString *> *)supportedEvents
{
    return @[ @"onStartedUpload", @"updateLookbackSetting" ];
}

- (NSDictionary *)constantsToExport
{
    NSString *appToken = [LookbackRecorder sharedRecorder].appToken ? [LookbackRecorder sharedRecorder].appToken : @"";
    return @{
        @"LookbackAfterRecordingReview" : @(LookbackAfterRecordingReview),
        @"LookbackAfterRecordingUpload" : @(LookbackAfterRecordingUpload),
        @"LookbackAfterTimeoutUploadAndStartNewRecording" : @(LookbackAfterTimeoutUploadAndStartNewRecording),
        @"onStartedUpload" : LookbackBridgeOnStartedUpload,
        @"updateLookbackSetting" : LookbackBridgeUpdateLookbackSetting,
        @"settings" : @{
            @"appToken" : appToken,
            @"shakeToRecord" : @([LookbackRecorder sharedRecorder].shakeToRecord),
            @"feedbackBubbleVisible" : @([LookbackRecorder sharedRecorder].feedbackBubbleVisible),
            @"paused" : @([LookbackRecorder sharedRecorder].paused),
            @"recording" : @([LookbackRecorder sharedRecorder].recording),
            @"recorderVisible" : @([LookbackRecorder sharedRecorder].recorderVisible),
            @"countOfRecordingsPendingUpload" : @([LookbackRecorder sharedRecorder].countOfRecordingsPendingUpload),
            @"uploadProgress" : @([LookbackRecorder sharedRecorder].uploadProgress),
            @"showIntroductionDialogs" : @([LookbackRecorder sharedRecorder].showIntroductionDialogs)
        }

    };
}

/**
 Register for UIApplicationDidFinishLaunchingNotification in order to pass
 Lookback the main app window Register this module with React Native
 */
+ (void)load
{
    [[NSNotificationCenter defaultCenter] addObserver:[[LookbackBridge alloc] init]
                                             selector:@selector(didFinishLaunching:)
                                                 name:UIApplicationDidFinishLaunchingNotification
                                               object:nil];
    RCTRegisterModule(self);
}

/**
 Override alloc to make LookbackBridge a singleton.
 This allows both RCTBridge to load this as a React Native Module
 and the UIResponder category to register it for didFinishLaunching

 @return LookbackBridge instance
 */
+ (id)alloc
{
    static LookbackBridge *bridgeInstance = nil;
    @synchronized(self) {
        if (bridgeInstance == nil) {
            bridgeInstance = [super alloc];
        }
    }
    return bridgeInstance;
}

/**
 Singleton Lookback Participate instance

 @return LookbackParticipate instance
 */
- (LookbackParticipate *)participate
{
    if (!_participate) {
        _participate = [LookbackParticipate new];
    }
    return _participate;
}

/**
 Handle didFinishLaunching notification from appDelegate
 - Register Lookback with the main app window
 - If didFinishLaunching was launched by a participate URL, then start the
 recording session
 - Add KVO observers for Lookback properties we are exposing
 @param notification Notification object, potentially contains URL used to launch app
 */
- (void)didFinishLaunching:(NSNotification *)notification
{
    UIWindow *appWindow = [[[UIApplication sharedApplication] delegate] window];
    [self.participate setupWithApplicationWindow:appWindow];
    // Getter/Setters
    [[LookbackRecorder sharedRecorder] addObserver:self
                                        forKeyPath:@"recording"
                                           options:NSKeyValueObservingOptionNew
                                           context:&LookbackStatusContext];
    [[LookbackRecorder sharedRecorder] addObserver:self
                                        forKeyPath:@"paused"
                                           options:NSKeyValueObservingOptionNew
                                           context:&LookbackStatusContext];
    [[LookbackRecorder sharedRecorder] addObserver:self
                                        forKeyPath:@"shakeToRecord"
                                           options:NSKeyValueObservingOptionNew
                                           context:&LookbackStatusContext];
    [[LookbackRecorder sharedRecorder] addObserver:self
                                        forKeyPath:@"feedbackBubbleVisible"
                                           options:NSKeyValueObservingOptionNew
                                           context:&LookbackStatusContext];
    [[LookbackRecorder sharedRecorder] addObserver:self
                                        forKeyPath:@"recorderVisible"
                                           options:NSKeyValueObservingOptionNew
                                           context:&LookbackStatusContext];
    [[LookbackRecorder sharedRecorder] addObserver:self
                                        forKeyPath:@"showIntroductionDialogs"
                                           options:NSKeyValueObservingOptionNew
                                           context:&LookbackStatusContext];
    // Getters
    [[LookbackRecorder sharedRecorder] addObserver:self
                                        forKeyPath:@"countOfRecordingsPendingUpload"
                                           options:NSKeyValueObservingOptionNew
                                           context:&LookbackStatusContext];
    [[LookbackRecorder sharedRecorder] addObserver:self
                                        forKeyPath:@"uploadProgress"
                                           options:NSKeyValueObservingOptionNew
                                           context:&LookbackStatusContext];

    NSURL *appUrl = [[notification userInfo] valueForKey:UIApplicationLaunchOptionsURLKey];
    if ([appUrl.scheme containsString:@"lookback"]) {
        [self.participate startParticipationFromURL:appUrl];
    }
}

- (void)dealloc
{
    [[LookbackRecorder sharedRecorder] removeObserver:self forKeyPath:@"recording"];
    [[LookbackRecorder sharedRecorder] removeObserver:self forKeyPath:@"paused"];
    [[LookbackRecorder sharedRecorder] removeObserver:self forKeyPath:@"shakeToRecord"];
    [[LookbackRecorder sharedRecorder] removeObserver:self forKeyPath:@"feedbackBubbleVisible"];
    [[LookbackRecorder sharedRecorder] removeObserver:self forKeyPath:@"recorderVisible"];
    [[LookbackRecorder sharedRecorder] removeObserver:self forKeyPath:@"showIntroductionDialogs"];
    [[LookbackRecorder sharedRecorder] removeObserver:self forKeyPath:@"countOfRecordingsPendingUpload"];
    [[LookbackRecorder sharedRecorder] removeObserver:self forKeyPath:@"uploadProgress"];
}

/**
 Track the state of Lookback properties and propagate them up to React Native
 via KVO

 @param keyPath Name of the Lookback property
 @param object Lookback instance
 @param change Change type
 @param context Context identifier
 */
- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context
{
    if (context == &LookbackStatusContext) {
        id setting = [[Lookback sharedRecorder] valueForKey:keyPath];
        [self sendEventWithName:LookbackBridgeUpdateLookbackSetting
                           body:@{keyPath : [[Lookback sharedRecorder] valueForKey:keyPath]}];
    }
}

/**
 Setter methods for Lookback properties

 */

RCT_EXPORT_METHOD(shakeToRecord : (BOOL)shouldShake)
{
    [LookbackRecorder sharedRecorder].shakeToRecord = shouldShake;
}

RCT_EXPORT_METHOD(recording : (BOOL)val)
{
    [LookbackRecorder sharedRecorder].recording = val;
}

RCT_EXPORT_METHOD(paused : (BOOL)val)
{
    [LookbackRecorder sharedRecorder].paused = val;
}

RCT_EXPORT_METHOD(showIntroductionDialogs : (BOOL)val)
{
    [LookbackRecorder sharedRecorder].showIntroductionDialogs = val;
}

RCT_EXPORT_METHOD(recorderVisible : (BOOL)val)
{
    [LookbackRecorder sharedRecorder].recorderVisible = val;
}

RCT_EXPORT_METHOD(feedbackBubbleVisible : (BOOL)bubble)
{
    [LookbackRecorder sharedRecorder].feedbackBubbleVisible = bubble;
}
/**
 Open a participate link that the user has clicked
 @note You should set your app to open the url scheme shown in your
 http://lookback.io dashboard in your Info.plist
 @param url The participate link
 */
RCT_EXPORT_METHOD(openURL : (NSString *)url)
{
    NSURL *parsedUrl = [NSURL URLWithString:url];
    [self.participate startParticipationFromURL:parsedUrl];
}

/**
 Setup LookbackRecorder with your team token
 @param token string reprsenting team token from http://lookback.io settings
 */
RCT_EXPORT_METHOD(setupWithAppToken : (NSString *)token)
{
    [LookbackRecorder setupWithAppToken:token];
    [self sendEventWithName:LookbackBridgeUpdateLookbackSetting body:@{@"appToken" : token}];
}

RCT_EXPORT_METHOD(startRecording)
{
    LookbackRecordingOptions *recorderOptions = [[LookbackRecorder sharedRecorder] options];
    recorderOptions.onStartedUpload = ^(NSURL *destinationURL, NSDate *sessionStartedAt) {
        [self sendEventWithName:LookbackBridgeOnStartedUpload
                           body:@{@"destinationURL" : destinationURL, @"sessionStartedAt" : sessionStartedAt}];
    };
    [[LookbackRecorder sharedRecorder] startRecordingWithOptions:recorderOptions];
}

RCT_EXPORT_METHOD(startRecordingWithOptions : (NSDictionary *)options)
{
    LookbackRecordingOptions *recorderOptions = [LookbackRecordingOptions new];

    if (options[LookbackBridgeAfterRecording]) {
        LookbackAfterRecordingOption afterRecording = (LookbackAfterRecordingOption)options[LookbackBridgeAfterRecording];
        recorderOptions.afterRecording = afterRecording;
    }
    if (options[LookbackBridgeTimeout]) {
        LookbackTimeoutOption timeout = (LookbackTimeoutOption)options[LookbackBridgeTimeout];
        recorderOptions.timeout = timeout;
    }
    if (options[LookbackBridgeCameraEnabled]) {
        recorderOptions.cameraEnabled = [RCTConvert BOOL:options[LookbackBridgeCameraEnabled]];
    }
    if (options[LookbackBridgeMicrophoneEnabled]) {
        recorderOptions.microphoneEnabled = [RCTConvert BOOL:options[LookbackBridgeMicrophoneEnabled]];
    }
    if (options[LookbackBridgeConsoleRecordingEnabled]) {
        recorderOptions.consoleRecordingEnabled = [RCTConvert BOOL:options[LookbackBridgeConsoleRecordingEnabled]];
    }
    if (options[LookbackBridgeShowCameraPreviewWhileRecording]) {
        recorderOptions.showCameraPreviewWhileRecording = [RCTConvert BOOL:options[LookbackBridgeShowCameraPreviewWhileRecording]];
    }
    if (options[LookbackBridgeFramerateLimit]) {
        recorderOptions.framerateLimit = [RCTConvert int:options[LookbackBridgeFramerateLimit]];
    }
    if (options[LookbackBridgeUserIdentifier]) {
        recorderOptions.userIdentifier = options[LookbackBridgeUserIdentifier];
    };
    if (options[LookbackBridgeUserFullName]) {
        recorderOptions.userFullName = options[LookbackBridgeUserFullName];
    };
    if (options[LookbackBridgeProjectId]) {
        recorderOptions.projectId = options[LookbackBridgeProjectId];
    };
    if (options[LookbackBridgeStudyId]) {
        recorderOptions.studyId = options[LookbackBridgeStudyId];
    };

    if (options[LookbackBridgeAllowSavingPreviewsAsDrafts]) {
        recorderOptions.allowSavingPreviewsAsDrafts = [RCTConvert BOOL:options[LookbackBridgeAllowSavingPreviewsAsDrafts]];
    }

    if (options[LookbackBridgeAllowResumeRecordingFromPreview]) {
        recorderOptions.allowResumeRecordingFromPreview = [RCTConvert BOOL:options[LookbackBridgeAllowResumeRecordingFromPreview]];
    }

    // In React Native we're not using View Controllers, so by default we turn
    // this off.
    if (options[LookbackBridgeAutomaticallyRecordViewControllerNames]) {
        recorderOptions.automaticallyRecordViewControllerNames =
            [RCTConvert BOOL:options[LookbackBridgeAutomaticallyRecordViewControllerNames]];
    } else {
        recorderOptions.automaticallyRecordViewControllerNames = NO;
    }

    recorderOptions.onStartedUpload = ^(NSURL *destinationURL, NSDate *sessionStartedAt) {
        [self sendEventWithName:LookbackBridgeOnStartedUpload
                           body:@{@"destinationURL" : destinationURL, @"sessionStartedAt" : sessionStartedAt}];
    };

    [[LookbackRecorder sharedRecorder] startRecordingWithOptions:recorderOptions];
}

RCT_EXPORT_METHOD(enteredView : (NSString *)viewName)
{
    [[LookbackRecorder sharedRecorder] enteredView:viewName];
}

RCT_EXPORT_METHOD(exitedView : (NSString *)viewName)
{
    [[LookbackRecorder sharedRecorder] exitedView:viewName];
}

RCT_EXPORT_METHOD(logEvent : (NSString *)event eventInfo : (NSString *)eventInfo)
{
    [[LookbackRecorder sharedRecorder] logEvent:event eventInfo:eventInfo];
}

RCT_EXPORT_METHOD(stopRecording)
{
    [[LookbackRecorder sharedRecorder] stopRecording];
}

@end

#pragma mark - Conversion for Lookback Enums

@implementation RCTConvert (LookbackAfterRecordingOption)
RCT_ENUM_CONVERTER(LookbackAfterRecordingOption,
                   (@{
                       @"LookbackAfterRecordingReview" : @(LookbackAfterRecordingReview),
                       @"LookbackAfterRecordingUpload" : @(LookbackAfterRecordingUpload),
                       @"LookbackAfterTimeoutUploadAndStartNewRecording" :
                           @(LookbackAfterTimeoutUploadAndStartNewRecording)
                   }),
                   LookbackAfterRecordingReview,
                   integerValue);
@end

@implementation RCTConvert (LookbackTimeoutOption)

RCT_ENUM_CONVERTER(LookbackTimeoutOption,
                   (@{
                       @"LookbackTimeoutImmediately" : @(LookbackTimeoutImmediately),
                       @"LookbackTimeoutAfter1Minutes" : @(LookbackTimeoutAfter1Minutes),
                       @"LookbackTimeoutAfter3Minutes" : @(LookbackTimeoutAfter3Minutes),
                       @"LookbackTimeoutAfter5Minutes" : @(LookbackTimeoutAfter5Minutes),
                       @"LookbackTimeoutAfter15Minutes" : @(LookbackTimeoutAfter15Minutes),
                       @"LookbackTimeoutAfter30Minutes" : @(LookbackTimeoutAfter30Minutes),
                       @"LookbackTimeoutNever" : @NSIntegerMax,
                   }),
                   LookbackTimeoutAfter1Minutes,
                   integerValue);

@end
