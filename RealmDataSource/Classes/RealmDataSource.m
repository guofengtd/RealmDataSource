//
//  RealmDataSource.m
//

#import "RealmDataSource.h"

@implementation RealmBaseObject

+ (NSString *)primaryKey {
    return @"uid";
}

@end

@interface RealmDataSource ()

@property (nonatomic, strong) RLMRealm              *realm;
@property (nonatomic, strong) NSMutableDictionary   *dicWatch;

@end

@implementation RealmDataSource

+ (instancetype)sharedClient {
    NSAssert(NO, @"Should be created in the sub classes");
    return nil;
}

- (instancetype)init {
    if (self = [super init]) {
        self.dicWatch = @{}.mutableCopy;
        
        RLMRealmConfiguration *config = [RLMRealmConfiguration defaultConfiguration];
        config.deleteRealmIfMigrationNeeded = YES;
        [RLMRealmConfiguration setDefaultConfiguration:config];
        
        self.realm = [RLMRealm defaultRealm];
    }
    
    return self;
}

- (void)watchWithClassName:(NSString *)className
                 predicate:(NSPredicate *)predicate
                      sort:(NSArray<RLMSortDescriptor *> *)sortDescriptors
               notifyBlock:(RLMNotifyBlock)notifyBlock
                       key:(NSString *)key {
    [self stopWatchForKey:key];
    
    RLMResults *results = [RLMGetObjects(self.realm, className, predicate) sortedResultsUsingDescriptors:sortDescriptors];
    RLMNotificationToken *token = [results addNotificationBlock:^(RLMResults * _Nullable results, RLMCollectionChange * _Nullable change, NSError * _Nullable error) {
        if (notifyBlock) {
            notifyBlock(results);
        }
    }];
    
    [self.dicWatch setObject:token forKey:key];
}

- (void)stopWatchForKey:(NSString *)key {
    RLMNotificationToken *token = self.dicWatch[key];
    if (token) {
        [token invalidate];
        
        [self.dicWatch removeObjectForKey:key];
    }
}

- (void)addObject:(RealmBaseObject *)object {
    [self addObjects:@[object]];
}

- (void)addObjects:(NSArray<RealmBaseObject *> *)array {
    [self addObjects:array
     objectClassName:nil
             syncAll:NO
           predicate:nil];
}

- (void)addObjects:(NSArray<RealmBaseObject *> *)array
   objectClassName:(NSString *)objectClassName
           syncAll:(BOOL)syncAll
         predicate:(NSPredicate *)predicate {
    if ((syncAll || predicate != nil) && objectClassName == nil) {
        NSAssert(NO, @"若要同步，就要明确指定类型");
    }
    
    if (!objectClassName) {
        objectClassName = [[array.firstObject class] className];
    }
    
    [self.realm transactionWithBlock:^{
        if (syncAll || predicate != nil) {
            RLMResults *results = RLMGetObjects(self.realm, objectClassName, predicate);
            for (RealmBaseObject *item in results) {
                item.refCount = 0;
            }
        }
        
        for (RealmBaseObject *item in array) {
            item.refCount = 1;
            
            [self.realm addOrUpdateObject:item];
        }
        
        if (objectClassName) {
            RLMResults *results = RLMGetObjects(self.realm, objectClassName, [NSPredicate predicateWithFormat:@"refCount == 0"]);
            for (RealmBaseObject *item in results) {
                [self.realm deleteObject:item];
            }
        }
    }];
}

- (void)deleteObjects:(id)array {
    [self.realm transactionWithBlock:^{
        [self.realm deleteObjects:array];
    }];
}

@end
