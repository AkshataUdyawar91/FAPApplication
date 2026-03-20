using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace BajajDocumentProcessing.Infrastructure.Migrations
{
    /// <inheritdoc />
    public partial class AddNotificationMultiChannelFields : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            // 1. Extend Notifications table with multi-channel delivery tracking fields
            migrationBuilder.AddColumn<int>(
                name: "Channel",
                table: "Notifications",
                type: "int",
                nullable: false,
                defaultValue: 1); // NotificationChannel.InApp

            migrationBuilder.AddColumn<int>(
                name: "DeliveryStatus",
                table: "Notifications",
                type: "int",
                nullable: false,
                defaultValue: 2); // NotificationDeliveryStatus.Sent

            migrationBuilder.AddColumn<int>(
                name: "RetryCount",
                table: "Notifications",
                type: "int",
                nullable: false,
                defaultValue: 0);

            migrationBuilder.AddColumn<DateTime>(
                name: "SentAt",
                table: "Notifications",
                type: "datetime2",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "ExternalMessageId",
                table: "Notifications",
                type: "nvarchar(500)",
                maxLength: 500,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "FailureReason",
                table: "Notifications",
                type: "nvarchar(2000)",
                maxLength: 2000,
                nullable: true);

            // 2. Extend RequestApprovalHistory table with Channel field
            migrationBuilder.AddColumn<string>(
                name: "Channel",
                table: "RequestApprovalHistory",
                type: "nvarchar(50)",
                maxLength: 50,
                nullable: true);

            // 3. Composite indexes for multi-channel notification queries
            migrationBuilder.CreateIndex(
                name: "IX_Notifications_UserId_Channel_DeliveryStatus",
                table: "Notifications",
                columns: new[] { "UserId", "Channel", "DeliveryStatus" });

            migrationBuilder.CreateIndex(
                name: "IX_Notifications_RelatedEntityId_Channel",
                table: "Notifications",
                columns: new[] { "RelatedEntityId", "Channel" });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            // Drop indexes first
            migrationBuilder.DropIndex(
                name: "IX_Notifications_RelatedEntityId_Channel",
                table: "Notifications");

            migrationBuilder.DropIndex(
                name: "IX_Notifications_UserId_Channel_DeliveryStatus",
                table: "Notifications");

            // Drop RequestApprovalHistory.Channel
            migrationBuilder.DropColumn(
                name: "Channel",
                table: "RequestApprovalHistory");

            // Drop Notification multi-channel columns
            migrationBuilder.DropColumn(
                name: "FailureReason",
                table: "Notifications");

            migrationBuilder.DropColumn(
                name: "ExternalMessageId",
                table: "Notifications");

            migrationBuilder.DropColumn(
                name: "SentAt",
                table: "Notifications");

            migrationBuilder.DropColumn(
                name: "RetryCount",
                table: "Notifications");

            migrationBuilder.DropColumn(
                name: "DeliveryStatus",
                table: "Notifications");

            migrationBuilder.DropColumn(
                name: "Channel",
                table: "Notifications");
        }
    }
}
