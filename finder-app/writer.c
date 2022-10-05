#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <syslog.h>

#define DEBUG(...)  syslog(LOG_DEBUG, __VA_ARGS__)
#define ERROR(...)  syslog(LOG_ERR, __VA_ARGS__)


int main(int argc, char *argv[])
{
	int fd, err;
	
	openlog(NULL, 0, LOG_USER);
	
	if (argc != 3) {
		ERROR("Could not creating the file");
		return EXIT_FAILURE;
	}
	
	DEBUG("Writing Whatever %s to %s", argv[2], argv[1]);

	fd = open(argv[1], O_CREAT | O_WRONLY, 0666);

	err = write(fd, argv[2], strlen(argv[2]));

	if (err == -1) {
		ERROR("Could not creating the file");
		return EXIT_FAILURE;
	}
	
	closelog();
	
	return EXIT_SUCCESS;
}


