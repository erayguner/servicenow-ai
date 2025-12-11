#!/usr/bin/env python3
"""
Simple Bedrock Agent Invocation Example

This example demonstrates the most basic way to create and invoke
a Bedrock agent for a simple task.
"""

import boto3
import uuid
from typing import Dict, Any

# Initialize Bedrock clients
bedrock_agent = boto3.client("bedrock-agent", region_name="eu-west-2")
bedrock_runtime = boto3.client("bedrock-agent-runtime", region_name="eu-west-2")


def create_simple_agent() -> str:
    """
    Create a simple Bedrock agent.

    Returns:
        str: Agent ID of the created agent
    """
    print("Creating simple Bedrock agent...")

    # Create agent
    response = bedrock_agent.create_agent(
        agentName="simple-assistant-agent",
        description="A simple assistant agent for basic queries",
        foundationModel="anthropic.claude-3-haiku-20240307-v1:0",
        agentInstruction="""You are a helpful assistant agent.
        Help users with their questions and provide clear, concise answers.
        Always be respectful and professional.""",
        agentResourceRoleArn="arn:aws:iam::ACCOUNT_ID:role/bedrock-agent-role",
    )

    agent_id = response["agent"]["agentId"]
    print(f"Agent created with ID: {agent_id}")

    # Prepare the agent (required before invocation)
    print("Preparing agent for invocation...")
    bedrock_agent.prepare_agent(agentId=agent_id)

    return agent_id


def invoke_agent(agent_id: str, user_query: str) -> Dict[str, Any]:
    """
    Invoke a Bedrock agent with a user query.

    Args:
        agent_id: The ID of the agent to invoke
        user_query: The user's query

    Returns:
        Dict containing the agent's response
    """
    print(f"\nInvoking agent with query: {user_query}")

    # Generate unique session ID for this interaction
    session_id = f"session-{uuid.uuid4()}"

    # Invoke the agent
    response = bedrock_runtime.invoke_agent(
        agentId=agent_id,
        agentAliasId="PROD",  # Use default alias
        sessionId=session_id,
        inputText=user_query,
    )

    return {
        "session_id": session_id,
        "output": response["output"],
        "agent_id": agent_id,
    }


def multi_turn_conversation(agent_id: str) -> None:
    """
    Demonstrate a multi-turn conversation with an agent.

    Args:
        agent_id: The ID of the agent to use
    """
    print("\n" + "=" * 60)
    print("MULTI-TURN CONVERSATION EXAMPLE")
    print("=" * 60)

    # Use same session ID to maintain conversation context
    session_id = f"conversation-{uuid.uuid4()}"

    queries = [
        "Hello! What can you help me with?",
        "I need help understanding AWS Bedrock agents",
        "Can you give me a quick summary?",
        "Thank you for the help!",
    ]

    for i, query in enumerate(queries, 1):
        print(f"\n[Turn {i}] User: {query}")

        response = bedrock_runtime.invoke_agent(
            agentId=agent_id,
            agentAliasId="PROD",
            sessionId=session_id,  # Reuse session for context
            inputText=query,
        )

        print(f"[Turn {i}] Agent: {response['output']}")


def main():
    """Main function to demonstrate simple agent usage."""

    print("=" * 60)
    print("SIMPLE BEDROCK AGENT EXAMPLE")
    print("=" * 60)

    # Note: In production, you would use an existing agent
    # This example shows how to create and use one
    # For existing agents, just use the agent_id directly

    # Example agent IDs (replace with your actual agent IDs)
    EXISTING_AGENT_ID = "AGENT_ID_FROM_DEPLOYMENT"

    # Single-turn conversation
    print("\n" + "=" * 60)
    print("SINGLE-TURN CONVERSATION EXAMPLE")
    print("=" * 60)

    queries = [
        "What is AWS Bedrock?",
        "How do I create a ServiceNow incident?",
        "Explain multi-agent orchestration",
    ]

    for query in queries:
        try:
            result = invoke_agent(EXISTING_AGENT_ID, query)
            print(f"\nResponse: {result['output']}")
            print(f"Session ID: {result['session_id']}")

        except Exception as e:
            print(f"Error invoking agent: {e}")

    # Multi-turn conversation
    try:
        multi_turn_conversation(EXISTING_AGENT_ID)
    except Exception as e:
        print(f"Error in multi-turn conversation: {e}")


if __name__ == "__main__":
    main()
