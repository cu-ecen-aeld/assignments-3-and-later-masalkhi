#include "threading.h"
#include <unistd.h>
#include <stdlib.h>
#include <stdio.h>
#include <errno.h>

// Optional: use these functions to add debug or error prints to your application
#define DEBUG_LOG(msg,...)
//#define DEBUG_LOG(msg,...) printf("threading: " msg "\n" , ##__VA_ARGS__)
#define ERROR_LOG(msg,...) printf("threading ERROR: " msg "\n" , ##__VA_ARGS__)

#define MIL_IN_SEC  (1000)
#define MAC_IN_MIL  (1000)
#define NANO_IN_MIL (MAC_IN_MIL * 1000)

#define GET_REST_IN_MILSEC(msec) ((msec % MIL_IN_SEC) * NANO_IN_MIL)


void * threadfunc(void *thread_param)
{
	struct thread_data *td = thread_param;
	struct timespec rem_release = {0}, rem_obtain = {0};
	
	if (!td)
		return td;
	
	int sec_obtain = td->wait_to_obtain_ms / 1000;
	int sec_release = td->wait_to_release_ms / 1000;
	struct timespec req_obtain = {
		.tv_sec = sec_obtain,
		.tv_nsec = GET_REST_IN_MILSEC(td->wait_to_obtain_ms),
	};
	struct timespec req_release = {
		.tv_sec = sec_release,
		.tv_nsec = GET_REST_IN_MILSEC(td->wait_to_release_ms),
	};
	
	while (nanosleep(&req_obtain, &rem_obtain)) {
		if (errno != EINTR) {
			ERROR_LOG("%s() could not sleep for obtain", __func__);
			goto error;
		}
		req_obtain = rem_obtain;
		rem_obtain = (struct timespec){0};
	}

	if (pthread_mutex_lock(td->mutex)) {
		ERROR_LOG("%s() could not hold mutex", __func__);
		goto error;
	}
	
	while (nanosleep(&req_release, &rem_release)) {
		if (errno != EINTR) {
			ERROR_LOG("%s() could not sleep for release", __func__);
			goto release_mutex;
		}
		req_obtain = rem_obtain;
		rem_obtain = (struct timespec){0};
	}
	
	pthread_mutex_unlock(td->mutex);
	
	td->thread_complete_success = true;
	return thread_param;
	
release_mutex:
	pthread_mutex_unlock(td->mutex);
error:
	td->thread_complete_success = false;
	return thread_param;
}


bool start_thread_obtaining_mutex(pthread_t *thread, pthread_mutex_t *mutex,
				  int wait_to_obtain_ms, int wait_to_release_ms)
{
	int err;
	struct thread_data *td = malloc(sizeof(struct thread_data));
	
	if (!thread || !mutex || !td)
		return false;

	*td = (struct thread_data) {
		.thread = thread,
		.mutex = mutex,
		.wait_to_obtain_ms = wait_to_obtain_ms,
		.wait_to_release_ms = wait_to_release_ms,
	};
	
	err = pthread_create(thread, NULL, threadfunc, td);
	if (err) {
		ERROR_LOG("%s() could not create the thread", __func__);
		return false;
	}
		
	return true;
}
