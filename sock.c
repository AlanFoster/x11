#include <stdio.h>
#include <sys/socket.h>
#include <arpa/inet.h>
#include <unistd.h>

int main() {
    int sockfd = socket(AF_INET, SOCK_STREAM, 0);

    const struct sockaddr_in addr = {
        .sin_family = AF_INET,
        .sin_addr = {
            .s_addr = inet_addr("127.0.0.1"),
        },
        .sin_port = htons(6000),
        .sin_zero = 0
    };

    int res = connect(sockfd, (struct sockaddr*)&addr, sizeof(addr));
    printf("sockfd: %x, res: %x\n", sockfd, res);
}
