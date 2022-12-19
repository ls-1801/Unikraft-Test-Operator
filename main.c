/* SPDX-License-Identifier: BSD-3-Clause */
/*
 * Authors: Simon Kuenzer <simon.kuenzer@neclab.eu>
 *
 * Copyright (c) 2019, NEC Laboratories Europe GmbH, NEC Corporation.
 *                     All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 *
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 * 3. Neither the name of the copyright holder nor the names of its
 *    contributors may be used to endorse or promote products derived from
 *    this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
 * LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
 */

#include <stdio.h>
#include <string.h>
#include <sys/socket.h>
#include <arpa/inet.h>
#include <unistd.h>
#include <errno.h>

#define LISTEN_PORT 8123
static const char reply[] = "HTTP/1.1 200 OK\r\n" \
			    "Content-type: text/html\r\n" \
			    "Connection: close\r\n" \
			    "\r\n" \
			    "<!DOCTYPE HTML PUBLIC \"-//IETF//DTD HTML 2.0//EN\">" \
			    "<html>" \
			    "<head><title>It works!</title></head>" \
			    "<body><h1>It works!</h1><p>This is only a test.</p></body>" \
			    "</html>\n";

#define BUFLEN 2048
static char recvbuf[BUFLEN];

int sent_boot_packet()
{
	int srv;
	int rc = 0;
	ssize_t n;
	struct sockaddr_in srv_addr;

	srv_addr.sin_family = AF_INET;
	lwip_inet_pton(AF_INET, "172.44.0.1", &srv_addr.sin_addr.s_addr);
	srv_addr.sin_port = htons(LISTEN_PORT);

	srv = socket(AF_INET, SOCK_DGRAM, 0);

	if (srv < 0)
	{
		fprintf(stderr, "Failed to create UDP socket: %d\n", errno);
		goto out;
	}

	const char *boot_message = "BOOTED!";
	size_t boot_message_len = strlen(boot_message);

	rc = sendto(srv, boot_message, boot_message_len, 0, &srv_addr, sizeof(struct sockaddr_in));
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

int main(int argc __attribute__((unused)),
	 char *argv[] __attribute__((unused)))
{
	sent_boot_packet();
	int rc = 0;
	int srv, client;
	ssize_t n;
	struct sockaddr_in srv_addr;

	srv = socket(AF_INET, SOCK_STREAM, 0);
	if (srv < 0) {
		fprintf(stderr, "Failed to create socket: %d\n", errno);
		goto out;
	}

	srv_addr.sin_family = AF_INET;
	srv_addr.sin_addr.s_addr = INADDR_ANY;
	srv_addr.sin_port = htons(LISTEN_PORT);

	rc = bind(srv, (struct sockaddr *) &srv_addr, sizeof(srv_addr));
	if (rc < 0) {
		fprintf(stderr, "Failed to bind socket: %d\n", errno);
		goto out;
	}

	/* Accept one simultaneous connection */
	rc = listen(srv, 1);
	if (rc < 0) {
		fprintf(stderr, "Failed to listen on socket: %d\n", errno);
		goto out;
	}

	printf("Listening on port %d...\n", LISTEN_PORT);
	while (1) {
		client = accept(srv, NULL, 0);
		if (client < 0) {
			fprintf(stderr,
				"Failed to accept incoming connection: %d\n",
				errno);
			goto out;
		}

		/* Receive some bytes (ignore errors) */
		read(client, recvbuf, BUFLEN);

		/* Send reply */
		n = write(client, reply, sizeof(reply) - 1);
		if (n < 0)
			fprintf(stderr, "Failed to send a reply\n");
		else
			printf("Sent a reply\n");

		/* Close connection */
		close(client);
	}

out:
	return rc;
}
