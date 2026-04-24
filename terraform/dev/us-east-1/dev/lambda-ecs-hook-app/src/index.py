# import re

# import logging
# import os

import boto3
from botocore.exceptions import ClientError

from aws_lambda_powertools import Logger
from aws_lambda_powertools.utilities.typing import LambdaContext

logger = Logger()

# Get the root logger
# logger = logging.getLogger()
# Set log level (often managed via environment variables)
# logger.setLevel(os.getenv("LOG_LEVEL", "INFO"))


def hook_succeeded():
    logger.info("hookStatus: SUCCEEDED")
    return {"hookStatus": "SUCCEEDED"}


def hook_failed():
    logger.info("hookStatus: FAILED")
    return {"hookStatus": "FAILED"}


# def validate_container_images(container_image_list):
#     # Regex patterns to match Amazon ECR repository URLs
#     # Format for private ECR: [account-id].dkr.ecr.[region].amazonaws.com/[repository-name]:[tag]
#     # Format for public ECR: public.ecr.aws/aws-containers/[repository-name]:[tag]
#     private_ecr_pattern = r"^(\d+)\.dkr\.ecr\.([a-z0-9-]+)\.amazonaws\.com/.*"
#     public_ecr_pattern = r"^public\.ecr\.aws/aws-containers/.*"

#     valid_images = True
#     for container_image in container_image_list:
#         image_url = container_image["image"]
#         logger.info(f"Validating image: {image_url}")

#         if re.match(private_ecr_pattern, image_url) or re.match(
#             public_ecr_pattern, image_url
#         ):
#             logger.info(f"Image {image_url} is from an Amazon ECR repository")
#         else:
#             logger.warning(f"Image {image_url} is NOT from an Amazon ECR repository")
#             valid_images = False

#     return valid_images


# def retrieve_container_images(task_definition_arn):
#     # Retrieve the task definition from the service revision arn
#     ecs_client = boto3.client("ecs")

#     logger.info(f"Retrieving Task Definition from {task_definition_arn}")
#     container_image_list = []
#     try:
#         response = ecs_client.describe_task_definition(
#             taskDefinition=task_definition_arn
#         )

#         task_definition = response["taskDefinition"]

#         logger.info(
#             f"Retrieved {len(task_definition['containerDefinitions'])} containers in task definition"
#         )
#         for container in task_definition["containerDefinitions"]:
#             container_image_list.append(
#                 {"name": container["name"], "image": container["image"]}
#             )

#         return container_image_list

#     except ClientError as e:
#         logger.error(f"Error retrieving task definition: {str(e)}")
#         return container_image_list


# Retrieve task definition from service revision arn
def retrieve_task_definition_arn(service_revision_arn):
    ecs_client = boto3.client("ecs")

    logger.info(f"Retrieving Service Revision details for {service_revision_arn}")
    try:
        response = ecs_client.describe_service_revisions(
            serviceRevisionArns=[service_revision_arn]
        )

        logger.debug(response)

        task_definition_arn = response["serviceRevisions"][0]["taskDefinition"]
        return task_definition_arn

    except ClientError as e:
        logger.error(f"Error retrieving service revision {service_revision_arn}: {str(e)}")
        return ""


@logger.inject_lambda_context
def lambda_handler(event: dict, context: LambdaContext) -> dict:
    logger.info(event)
    logger.info(context)

    for var in ["serviceArn", "targetServiceRevisionArn"]:
        if var not in event["executionDetails"]:
            error_message = f"Event missing required var {var}"
            logger.error(error_message)
            raise Exception(error_message)

    # service_revision = event["executionDetails"]["targetServiceRevisionArn"]

    # Retrieve Task Definition Arn from the service revision
    # task_definition_arn = retrieve_task_definition_arn(service_revision)
    # if not task_definition_arn:
    #     return hook_failed()

    # # Retrieve Container Images
    # container_image_list = retrieve_container_images(task_definition_arn)
    # if not container_image_list:
    #     return hook_failed()

    # # Validate the container images come from Amazon ECR
    # valid_container_images = validate_container_images(container_image_list)
    # if not valid_container_images:
    #     return hook_failed()

    return hook_succeeded()
