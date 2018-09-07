#import "JPushPlugin.h"
#ifdef NSFoundationVersionNumber_iOS_9_x_Max
#import <UserNotifications/UserNotifications.h>
#endif

#import <JPush/JPUSHService.h>

@interface NSError (FlutterError)
@property(readonly, nonatomic) FlutterError *flutterError;
@end

@implementation NSError (FlutterError)
- (FlutterError *)flutterError {
  return [FlutterError errorWithCode:[NSString stringWithFormat:@"Error %d", (int)self.code]
                             message:self.domain
                             details:self.localizedDescription];
}
@end


#if defined(__IPHONE_10_0) && __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_10_0
@interface JPushPlugin ()<JPUSHRegisterDelegate>
@end
#endif

static NSMutableArray<FlutterResult>* getRidResults;

@implementation JPushPlugin {
  NSDictionary *_launchNotification;
  BOOL _isJPushDidLogin;
  JPAuthorizationOptions notificationTypes;
}

+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  getRidResults = @[].mutableCopy;
  FlutterMethodChannel* channel = [FlutterMethodChannel
      methodChannelWithName:@"jpush"
            binaryMessenger:[registrar messenger]];
  JPushPlugin* instance = [[JPushPlugin alloc] init];
  instance.channel = channel;
  
  
  [registrar addApplicationDelegate:instance];
  [registrar addMethodCallDelegate:instance channel:channel];
}

- (id)init {
  self = [super init];
  notificationTypes = 0;
  NSNotificationCenter *defaultCenter = [NSNotificationCenter defaultCenter];
  
  [defaultCenter removeObserver:self];
  
  
  [defaultCenter addObserver:self
                    selector:@selector(networkConnecting:)
                        name:kJPFNetworkIsConnectingNotification
                      object:nil];
  
  [defaultCenter addObserver:self
                    selector:@selector(networkRegister:)
                        name:kJPFNetworkDidRegisterNotification
                      object:nil];
  
  [defaultCenter addObserver:self
                    selector:@selector(networkDidSetup:)
                        name:kJPFNetworkDidSetupNotification
                      object:nil];
  [defaultCenter addObserver:self
                    selector:@selector(networkDidClose:)
                        name:kJPFNetworkDidCloseNotification
                      object:nil];
  [defaultCenter addObserver:self
                    selector:@selector(networkDidLogin:)
                        name:kJPFNetworkDidLoginNotification
                      object:nil];
  [defaultCenter addObserver:self
                    selector:@selector(networkDidReceiveMessage:)
                        name:kJPFNetworkDidReceiveMessageNotification
                      object:nil];
  return self;
}

- (void)networkConnecting:(NSNotification *)notification {
  _isJPushDidLogin = false;
}

- (void)networkRegister:(NSNotification *)notification {
  _isJPushDidLogin = false;
}

- (void)networkDidSetup:(NSNotification *)notification {
  _isJPushDidLogin = false;
}

- (void)networkDidClose:(NSNotification *)notification {
  _isJPushDidLogin = false;
}


- (void)networkDidLogin:(NSNotification *)notification {
  _isJPushDidLogin = YES;
  for (FlutterResult result in getRidResults) {
    result([JPUSHService registrationID]);
  }
  [getRidResults removeAllObjects];
}

- (void)networkDidReceiveMessage:(NSNotification *)notification {
  [_channel invokeMethod:@"onReceiveMessage" arguments: [notification userInfo]];
}

- (void)handleMethodCall:(FlutterMethodCall*)call result:(FlutterResult)result {
  if ([@"getPlatformVersion" isEqualToString:call.method]) {
    result([@"iOS " stringByAppendingString:[[UIDevice currentDevice] systemVersion]]);
  } else if([@"setup" isEqualToString:call.method]) {
    [self setup:call result: result];
  } else if([@"applyPushAuthority" isEqualToString:call.method]) {
    [self applyPushAuthority:call result:result];
  } else if([@"setTags" isEqualToString:call.method]) {
    [self setTags:call result:result];
  } else if([@"cleanTags" isEqualToString:call.method]) {
    [self cleanTags:call result:result];
  } else if([@"addTags" isEqualToString:call.method]) {
    [self addTags:call result:result];
  } else if([@"deleteTags" isEqualToString:call.method]) {
    [self deleteTags:call result:result];
  } else if([@"getAllTags" isEqualToString:call.method]) {
    [self getAllTags:call result:result];
  } else if([@"setAlias" isEqualToString:call.method]) {
    [self setAlias:call result:result];
  } else if([@"deleteAlias" isEqualToString:call.method]) {
    [self deleteAlias:call result:result];
  } else if([@"setBadge" isEqualToString:call.method]) {
    [self setBadge:call result:result];
  } else if([@"stopPush" isEqualToString:call.method]) {
    [self stopPush:call result:result];
  } else if([@"resumePush" isEqualToString:call.method]) {
    [self applyPushAuthority:call result:result];
  } else if([@"clearAllNotifications" isEqualToString:call.method]) {
    [self clearAllNotifications:call result:result];
  } else if([@"getLaunchAppNotification" isEqualToString:call.method]) {
    [self getLaunchAppNotification:call result:result];
  } else if([@"getRegistrationID" isEqualToString:call.method]) {
    [self getRegistrationID:call result:result];
  }
  
  else{
    result(FlutterMethodNotImplemented);
  }
}

- (void)setup:(FlutterMethodCall*)call result:(FlutterResult)result {
  NSDictionary *arguments = call.arguments;
  
  [JPUSHService setupWithOption:_launchNotification
                         appKey:arguments[@"appKey"]
                        channel:arguments[@"channel"]
               apsForProduction:[arguments[@"production"] boolValue]];
}

- (void)applyPushAuthority:(FlutterMethodCall*)call result:(FlutterResult)result {
  notificationTypes = 0;
  NSDictionary *arguments = call.arguments;
  if ([arguments[@"sound"] boolValue]) {
    notificationTypes |= JPAuthorizationOptionSound;
  }
  if ([arguments[@"alert"] boolValue]) {
    notificationTypes |= JPAuthorizationOptionAlert;
  }
  if ([arguments[@"badge"] boolValue]) {
    notificationTypes |= JPAuthorizationOptionBadge;
  }
  JPUSHRegisterEntity * entity = [[JPUSHRegisterEntity alloc] init];
  entity.types = notificationTypes;
  [JPUSHService registerForRemoteNotificationConfig:entity delegate:self];
}

- (void)setTags:(FlutterMethodCall*)call result:(FlutterResult)result {
  NSSet *tagSet;
  
  if (call.arguments != NULL) {
    tagSet = [NSSet setWithArray: call.arguments];
  }
  
  [JPUSHService setTags:tagSet completion:^(NSInteger iResCode, NSSet *iTags, NSInteger seq) {
    if (iResCode == 0) {
      result(@{@"tags": [iTags allObjects] ?: @[]});
    } else {
      NSError *error = [[NSError alloc] initWithDomain:@"JPush.Flutter" code:iResCode userInfo:nil];
      result([error flutterError]);
    }
  } seq: 0];
}

- (void)cleanTags:(FlutterMethodCall*)call result:(FlutterResult)result {
  [JPUSHService cleanTags:^(NSInteger iResCode, NSSet *iTags, NSInteger seq) {
    if (iResCode == 0) {
      result(@{@"tags": iTags ? [iTags allObjects] : @[]});
    } else {
      NSError *error = [[NSError alloc] initWithDomain:@"JPush.Flutter" code:iResCode userInfo:nil];
      result([error flutterError]);
    }
  } seq: 0];
}

- (void)addTags:(FlutterMethodCall*)call result:(FlutterResult)result {
  NSSet *tagSet;
  
  if (call.arguments != NULL) {
    tagSet = [NSSet setWithArray:call.arguments];
  }
  
  [JPUSHService addTags:tagSet completion:^(NSInteger iResCode, NSSet *iTags, NSInteger seq) {
    if (iResCode == 0) {
      result(@{@"tags": [iTags allObjects] ?: @[]});
    } else {
      NSError *error = [[NSError alloc] initWithDomain:@"JPush.Flutter" code:iResCode userInfo:nil];
      result([error flutterError]);
    }
  } seq: 0];
}

- (void)deleteTags:(FlutterMethodCall*)call result:(FlutterResult)result {
  NSSet *tagSet;
  
  if (call.arguments != NULL) {
    tagSet = [NSSet setWithArray:call.arguments];
  }
  
  [JPUSHService deleteTags:tagSet completion:^(NSInteger iResCode, NSSet *iTags, NSInteger seq) {
    if (iResCode == 0) {
      result(@{@"tags": [iTags allObjects] ?: @[]});
    } else {
      NSError *error = [[NSError alloc] initWithDomain:@"JPush.Flutter" code:iResCode userInfo:nil];
      result([error flutterError]);
    }
  } seq: 0];
}

- (void)getAllTags:(FlutterMethodCall*)call result:(FlutterResult)result {
  [JPUSHService getAllTags:^(NSInteger iResCode, NSSet *iTags, NSInteger seq) {
    if (iResCode == 0) {
      result(@{@"tags": iTags ? [iTags allObjects] : @[]});
    } else {
      NSError *error = [[NSError alloc] initWithDomain:@"JPush.Flutter" code:iResCode userInfo:nil];
      result([error flutterError]);
    }
  } seq: 0];
}

- (void)setAlias:(FlutterMethodCall*)call result:(FlutterResult)result {
  NSString *alias = call.arguments;
  [JPUSHService setAlias:alias completion:^(NSInteger iResCode, NSString *iAlias, NSInteger seq) {
    if (iResCode == 0) {
      result(@{@"alias": iAlias ?: @""});
    } else {
      NSError *error = [[NSError alloc] initWithDomain:@"JPush.Flutter" code:iResCode userInfo:nil];
      result([error flutterError]);
    }
  } seq: 0];
}

- (void)deleteAlias:(FlutterMethodCall*)call result:(FlutterResult)result {
  [JPUSHService deleteAlias:^(NSInteger iResCode, NSString *iAlias, NSInteger seq) {
    if (iResCode == 0) {
      result(@{@"alias": iAlias ?: @""});
    } else {
      NSError *error = [[NSError alloc] initWithDomain:@"JPush.Flutter" code:iResCode userInfo:nil];
      result([error flutterError]);
    }
  } seq: 0];
}

- (void)setBadge:(FlutterMethodCall*)call result:(FlutterResult)result {
  NSNumber *badge = call.arguments;
  [[UIApplication sharedApplication] setApplicationIconBadgeNumber: badge.integerValue];
  [JPUSHService setBadge: badge.integerValue > 0 ? badge.integerValue: 0];
}

- (void)stopPush:(FlutterMethodCall*)call result:(FlutterResult)result {
  [[UIApplication sharedApplication] unregisterForRemoteNotifications];
}

- (void)clearAllNotifications:(FlutterMethodCall*)call result:(FlutterResult)result {
  [[UIApplication sharedApplication] setApplicationIconBadgeNumber: 0];
}

- (void)getLaunchAppNotification:(FlutterMethodCall*)call result:(FlutterResult)result {
  NSDictionary *notification;
  notification = [_launchNotification objectForKey:UIApplicationLaunchOptionsRemoteNotificationKey];
  
  if ([_launchNotification objectForKey:UIApplicationLaunchOptionsLocalNotificationKey]) {
    UILocalNotification *localNotification = [_launchNotification objectForKey:UIApplicationLaunchOptionsLocalNotificationKey];
    notification = localNotification.userInfo;
  }
  result(notification);
}

- (void)getRegistrationID:(FlutterMethodCall*)call result:(FlutterResult)result {
#if TARGET_IPHONE_SIMULATOR//模拟器
  NSLog(@"simulator can not get registrationid");
  result(@"");
#elif TARGET_OS_IPHONE//真机
  
  if ([JPUSHService registrationID] != nil && ![[JPUSHService registrationID] isEqualToString:@""]) {
    // 如果已经成功获取 registrationID，从本地获取直接缓存
    result([JPUSHService registrationID]);
    return;
  }
  
  if (_isJPushDidLogin) {// 第一次获取未登录情况
    result(@[[JPUSHService registrationID]]);
  } else {
    [getRidResults addObject:result];
  }
#endif
}

- (void)dealloc {
  _isJPushDidLogin = NO;
  [[NSNotificationCenter defaultCenter] removeObserver:self];
}


#pragma mark - AppDelegate

- (BOOL)application:(UIApplication *)application
didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
  
  if (launchOptions != nil) {
    _launchNotification = launchOptions[UIApplicationLaunchOptionsRemoteNotificationKey];
    
  }
  return YES;
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
//  _resumingFromBackground = YES;
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
//  _resumingFromBackground = NO;
  // Clears push notifications from the notification center, with the
  // side effect of resetting the badge count. We need to clear notifications
  // because otherwise the user could tap notifications in the notification
  // center while the app is in the foreground, and we wouldn't be able to
  // distinguish that case from the case where a message came in and the
  // user dismissed the notification center without tapping anything.
  // TODO(goderbauer): Revisit this behavior once we provide an API for managing
  // the badge number, or if we add support for running Dart in the background.
  // Setting badgeNumber to 0 is a no-op (= notifications will not be cleared)
  // if it is already 0,
  // therefore the next line is setting it to 1 first before clearing it again
  // to remove all
  // notifications.
  application.applicationIconBadgeNumber = 1;
  application.applicationIconBadgeNumber = 0;
}

- (bool)application:(UIApplication *)application
didReceiveRemoteNotification:(NSDictionary *)userInfo
fetchCompletionHandler:(void (^)(UIBackgroundFetchResult result))completionHandler {
//  [self didReceiveRemoteNotification:userInfo];

  [_channel invokeMethod:@"onReceiveNotification" arguments:userInfo];
  completionHandler(UIBackgroundFetchResultNoData);
  return YES;
}

- (void)application:(UIApplication *)application
didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken {
  [JPUSHService registerDeviceToken:deviceToken];
}

- (void)application:(UIApplication *)application
didRegisterUserNotificationSettings:(UIUserNotificationSettings *)notificationSettings {
  NSDictionary *settingsDictionary = @{
                                       @"sound" : [NSNumber numberWithBool:notificationSettings.types & UIUserNotificationTypeSound],
                                       @"badge" : [NSNumber numberWithBool:notificationSettings.types & UIUserNotificationTypeBadge],
                                       @"alert" : [NSNumber numberWithBool:notificationSettings.types & UIUserNotificationTypeAlert],
                                       };
  [_channel invokeMethod:@"onIosSettingsRegistered" arguments:settingsDictionary];
}



- (void)jpushNotificationCenter:(UNUserNotificationCenter *)center willPresentNotification:(UNNotification *)notification withCompletionHandler:(void (^)(NSInteger))completionHandler {
  
  
  NSDictionary * userInfo = notification.request.content.userInfo;
  if([notification.request.trigger isKindOfClass:[UNPushNotificationTrigger class]]) {
    [JPUSHService handleRemoteNotification:userInfo];
    [_channel invokeMethod:@"onReceiveNotification" arguments: userInfo];
  }
  

  completionHandler(notificationTypes);
}

- (void)jpushNotificationCenter:(UNUserNotificationCenter *)center didReceiveNotificationResponse:(UNNotificationResponse *)response withCompletionHandler:(void (^)())completionHandler {
  NSDictionary * userInfo = response.notification.request.content.userInfo;
  if([response.notification.request.trigger isKindOfClass:[UNPushNotificationTrigger class]]) {
    [JPUSHService handleRemoteNotification:userInfo];
//    [[NSNotificationCenter defaultCenter] postNotificationName:@"kJPFOpenNotification" object:userInfo];
    [_channel invokeMethod:@"onOpenNotification" arguments: userInfo];
    
  }
  completionHandler();
}

@end