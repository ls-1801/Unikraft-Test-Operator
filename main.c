/* Import user configuration: */
#ifdef __Unikraft__
#include <uk/config.h>
#endif /* __Unikraft__ */

#include <stdio.h>
#include <lwip/netif.h>
#include <lwip/ip.h>
#include <lwip/dhcp.h>
#include <lwip/timeouts.h>
#include <string.h>
#include <sys/socket.h>
#include <arpa/inet.h>
#include <unistd.h>
#include <time.h>
#include <errno.h>

#define LISTEN_PORT 8123
#define BUFLEN 2048
static char recvbuf[BUFLEN];

int sent_boot_packet()
{
	int srv;
	int rc = 0;
	ssize_t n;
	struct sockaddr_in srv_addr;

	srv_addr.sin_family = AF_INET;
	lwip_inet_pton(AF_INET, CONFIG_APPTESTOPERATOR_TESTBENCH_ADDR, &srv_addr.sin_addr.s_addr);
	srv_addr.sin_port = htons(CONFIG_APPTESTOPERATOR_TESTBENCH_PORT);

	srv = socket(AF_INET, SOCK_DGRAM, 0);

	if (srv < 0)
	{
		fprintf(stderr, "Failed to create UDP socket: %d\n", errno);
		goto out;
	}

	const char *boot_message = "BOOTED!";
	size_t boot_message_len = strlen(boot_message);

	rc = sendto(srv, boot_message, boot_message_len, 0, (const struct sockaddr *)&srv_addr, sizeof(struct sockaddr_in));
	printf("Boot package sent!\n");
	if (rc < 0)
	{
		fprintf(stderr, "Failed to send a reply\n");
		goto out;
	}

	close(srv);

out:
	return rc;
}

int process_tuples()
{
	int source_fd;
	int rc = 0;
	ssize_t n;
	struct sockaddr_in src_addr;

	src_addr.sin_family = AF_INET;
	lwip_inet_pton(AF_INET, CONFIG_APPTESTOPERATOR_SOURCE_ADDR, &src_addr.sin_addr.s_addr);
	src_addr.sin_port = htons(CONFIG_APPTESTOPERATOR_SOURCE_PORT);

	source_fd = socket(AF_INET, SOCK_STREAM, 0);

	if (source_fd < 0)
	{
		fprintf(stderr, "Failed to create TCP socket: %d\n", errno);
		goto end;
	}

	rc = connect(source_fd, &src_addr, sizeof(struct sockaddr_in));

	if (rc < 0)
	{
		fprintf(stderr, "Failed to Connect: %d\n", rc);
		goto close;
	}

	printf("Connected to Source!\n");

	const char *request_tuple_message = "SEND TUPLES!";
	size_t request_tuple_message_len = strlen(request_tuple_message);

	rc = send(source_fd, request_tuple_message, request_tuple_message_len, 0);

	if (rc < 0)
	{
		fprintf(stderr, "Failed to send request for tuples: %d\n", rc);
		goto close;
	}

	while (1)
	{
		rc = recv(source_fd, recvbuf, BUFLEN, 0);
		if (rc < 0)
		{
			fprintf(stderr, "Failed to receive: %d\n", rc);
			goto close;
		}
		printf("Tuple: %.*s\n", rc, recvbuf);
	}

close:
	close(source_fd);
end:
	return rc;
}

static void millisleep(unsigned int millisec)
{
	struct timespec ts;
	int ret;

	ts.tv_sec = millisec / 1000;
	ts.tv_nsec = (millisec % 1000) * 1000000;
	do
		ret = nanosleep(&ts, &ts);
	while (ret && errno == EINTR);
}

int main(int argc __attribute__((unused)),
		 char *argv[] __attribute__((unused)))
{
	struct netif *netif = netif_find("en1");
	while (netif_dhcp_data(netif)->state != 10)
	{
		millisleep(1);
	}

	uk_pr_debug_once("Booted %s", "yo");

	printf("DHCP Ready\n");
	sent_boot_packet();
	millisleep(1000);
	process_tuples();
	return 0;
}
