export class AquiverPromise<T> {
    public resolve!: (value: T | PromiseLike<T>) => void;
    public reject!: (reason?: any) => void;
    private promise!: Promise<T>;

    constructor() {
        this.promise = new Promise<T>((resolve, reject) => {
            this.resolve = resolve;
            this.reject = reject;
        });
    }

    then(onFulfilled?: ((value: T) => T | PromiseLike<T>) | undefined | null, onRejected?: ((reason: any) => T | PromiseLike<T>) | undefined | null) {
        return this.promise.then(onFulfilled, onRejected);
    }

    catch(onRejected?: ((reason: any) => T | PromiseLike<T>) | undefined | null) {
        return this.promise.catch(onRejected);
    }

    finally(onFinally?: (() => void) | undefined | null) {
        return this.promise.finally(onFinally);
    }
}