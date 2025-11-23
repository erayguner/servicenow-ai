#!/usr/bin/env python3
"""
Multi-Agent Coordination Example

This example demonstrates coordinating multiple specialized agents
using AWS Step Functions to achieve complex tasks.
"""

import boto3
import json
import uuid
import time
from typing import Dict, Any, List, Optional
from dataclasses import dataclass
from enum import Enum

# Initialize clients
bedrock_runtime = boto3.client("bedrock-agent-runtime", region_name="us-east-1")
stepfunctions = boto3.client("stepfunctions", region_name="us-east-1")


@dataclass
class AgentConfig:
    """Configuration for an agent."""

    id: str
    alias: str = "PROD"
    name: str = ""


class AgentRole(Enum):
    """Different roles agents can play."""

    RESEARCHER = "researcher"
    ANALYZER = "analyzer"
    WRITER = "writer"
    REVIEWER = "reviewer"


class MultiAgentOrchestrator:
    """Orchestrate multiple agents for complex tasks."""

    def __init__(self, agents: Dict[str, AgentConfig]):
        """
        Initialize orchestrator with agents.

        Args:
            agents: Dictionary mapping agent names to configurations
        """
        self.agents = agents
        self.session_id = f"orchestration-{uuid.uuid4()}"
        self.execution_log: List[Dict[str, Any]] = []

    def invoke_agent(
        self, agent_name: str, query: str, context: Optional[Dict[str, Any]] = None
    ) -> str:
        """
        Invoke a specific agent.

        Args:
            agent_name: Name of the agent to invoke
            query: The query to send to the agent
            context: Additional context for the agent

        Returns:
            The agent's response text
        """
        if agent_name not in self.agents:
            raise ValueError(f"Agent '{agent_name}' not found")

        agent_config = self.agents[agent_name]

        # Prepare input with context
        if context:
            full_query = f"{query}\n\nContext: {json.dumps(context)}"
        else:
            full_query = query

        print(f"\n[{agent_name}] Invoking with query: {query[:50]}...")

        try:
            response = bedrock_runtime.invoke_agent(
                agentId=agent_config.id,
                agentAliasId=agent_config.alias,
                sessionId=self.session_id,
                inputText=full_query,
            )

            output = response["output"]

            # Log execution
            self.execution_log.append(
                {
                    "agent": agent_name,
                    "query": query,
                    "response": output,
                    "timestamp": time.time(),
                }
            )

            print(f"[{agent_name}] Response: {output[:100]}...")
            return output

        except Exception as e:
            print(f"[{agent_name}] Error: {e}")
            raise

    def sequential_workflow(
        self, task: str, agent_sequence: List[str]
    ) -> Dict[str, Any]:
        """
        Execute agents sequentially, passing output to next agent.

        Example workflow:
            Research Agent -> Analyzer Agent -> Writer Agent

        Args:
            task: Initial task description
            agent_sequence: List of agent names in execution order

        Returns:
            Final result from last agent
        """
        print(f"\n{'='*60}")
        print(f"SEQUENTIAL WORKFLOW: {' -> '.join(agent_sequence)}")
        print(f"{'='*60}")

        current_output = task
        results: Dict[str, Any] = {}

        for i, agent_name in enumerate(agent_sequence):
            print(f"\n[Step {i+1}/{len(agent_sequence)}] Invoking {agent_name}")

            context = {
                "previous_outputs": results,
                "step": i + 1,
                "total_steps": len(agent_sequence),
            }

            output = self.invoke_agent(
                agent_name, f"Process this: {current_output}", context
            )

            results[agent_name] = output
            current_output = output

        return {
            "final_output": current_output,
            "intermediate_results": results,
            "execution_log": self.execution_log,
        }

    def parallel_workflow(
        self, task: str, agent_group: Dict[str, str]
    ) -> Dict[str, Any]:
        """
        Execute multiple agents in parallel on the same task.

        Example workflow:
            ├─ Research Agent (parallel)
            ├─ Fact Checker Agent (parallel)
            └─ Bias Detector Agent (parallel)

        Args:
            task: Task to execute
            agent_group: Dict mapping agent names to their focus areas

        Returns:
            Aggregated results from all agents
        """
        print(f"\n{'='*60}")
        print(f"PARALLEL WORKFLOW: {list(agent_group.keys())}")
        print(f"{'='*60}")

        results = {}
        import concurrent.futures

        def invoke_for_group(agent_name: str, focus: str) -> tuple:
            """Invoke agent with specific focus."""
            query = f"{task}\n\nFocus on: {focus}"
            output = self.invoke_agent(agent_name, query)
            return agent_name, output

        with concurrent.futures.ThreadPoolExecutor(max_workers=3) as executor:
            futures = {
                executor.submit(invoke_for_group, name, focus): name
                for name, focus in agent_group.items()
            }

            for future in concurrent.futures.as_completed(futures):
                agent_name, output = future.result()
                results[agent_name] = output

        return {"parallel_results": results, "execution_log": self.execution_log}

    def conditional_workflow(
        self, task: str, router_agent: str, specialized_agents: Dict[str, str]
    ) -> Dict[str, Any]:
        """
        Use router agent to decide which specialized agent to invoke.

        Example:
            Router decides -> routes to appropriate specialist

        Args:
            task: Initial task
            router_agent: Agent that decides routing
            specialized_agents: Dict of specialist agents

        Returns:
            Result from selected specialist
        """
        print(f"\n{'='*60}")
        print("CONDITIONAL WORKFLOW")
        print(f"{'='*60}")

        # Step 1: Router decides
        print("\n[Step 1] Router analysis...")
        router_response = self.invoke_agent(
            router_agent,
            f"Analyze this task and decide which agent should handle it: {task}\n\n"
            f"Available agents: {', '.join(specialized_agents.keys())}\n"
            f"Respond with ONLY the agent name.",
        )

        selected_agent = router_response.strip().lower()

        # Find best matching agent
        if selected_agent not in specialized_agents:
            selected_agent = list(specialized_agents.keys())[0]

        print(f"\n[Step 2] Routing to specialist: {selected_agent}")

        # Step 2: Specialist processes task
        specialist_output = self.invoke_agent(
            selected_agent, task, {"routed_from": router_agent}
        )

        return {
            "router_decision": router_response,
            "selected_agent": selected_agent,
            "specialist_output": specialist_output,
            "execution_log": self.execution_log,
        }

    def voting_consensus(
        self, proposition: str, voting_agents: List[str], threshold: float = 0.5
    ) -> Dict[str, Any]:
        """
        Have multiple agents vote on a proposition.

        Args:
            proposition: Statement to vote on
            voting_agents: Agents that will vote
            threshold: Approval threshold (0.0 to 1.0)

        Returns:
            Voting results and consensus decision
        """
        print(f"\n{'='*60}")
        print(f"VOTING CONSENSUS: {proposition}")
        print(f"{'='*60}")

        votes = {}
        reasoning = {}

        for agent_name in voting_agents:
            vote_prompt = (
                f"Do you approve of this proposition? "
                f"'{proposition}'\n\n"
                f"Respond with either APPROVE or REJECT, "
                f"then explain your reasoning."
            )

            response = self.invoke_agent(agent_name, vote_prompt)

            # Simple vote extraction (in production, use more robust parsing)
            if "approve" in response.lower():
                votes[agent_name] = "APPROVE"
            else:
                votes[agent_name] = "REJECT"

            reasoning[agent_name] = response

        # Calculate consensus
        approvals = sum(1 for v in votes.values() if v == "APPROVE")
        approval_ratio = approvals / len(votes)
        consensus = approval_ratio >= threshold

        return {
            "proposition": proposition,
            "votes": votes,
            "reasoning": reasoning,
            "approval_ratio": approval_ratio,
            "consensus_reached": consensus,
            "decision": "APPROVED" if consensus else "REJECTED",
            "execution_log": self.execution_log,
        }

    def print_summary(self) -> None:
        """Print summary of orchestration execution."""
        print(f"\n{'='*60}")
        print("EXECUTION SUMMARY")
        print(f"{'='*60}")

        print(f"Session ID: {self.session_id}")
        print(f"Total steps: {len(self.execution_log)}")

        for i, log_entry in enumerate(self.execution_log, 1):
            print(f"\n[{i}] {log_entry['agent']}")
            print(f"    Query: {log_entry['query'][:50]}...")
            print(f"    Response: {log_entry['response'][:50]}...")


def main():
    """Main function demonstrating multi-agent orchestration."""

    # Define agents
    agents = {
        "research-agent": AgentConfig(id="RESEARCH_AGENT_ID", name="research-agent"),
        "analyzer-agent": AgentConfig(id="ANALYZER_AGENT_ID", name="analyzer-agent"),
        "writer-agent": AgentConfig(id="WRITER_AGENT_ID", name="writer-agent"),
        "router-agent": AgentConfig(id="ROUTER_AGENT_ID", name="router-agent"),
    }

    # Create orchestrator
    orchestrator = MultiAgentOrchestrator(agents)

    # Example 1: Sequential Workflow
    print("\n" + "=" * 60)
    print("EXAMPLE 1: SEQUENTIAL WORKFLOW")
    print("=" * 60)

    try:
        result = orchestrator.sequential_workflow(
            task="Analyze the impact of AI on software development",
            agent_sequence=["research-agent", "analyzer-agent", "writer-agent"],
        )
        print(f"\nFinal Output: {result['final_output']}")
    except Exception as e:
        print(f"Error in sequential workflow: {e}")

    # Example 2: Parallel Workflow
    print("\n" + "=" * 60)
    print("EXAMPLE 2: PARALLEL WORKFLOW")
    print("=" * 60)

    try:
        result = orchestrator.parallel_workflow(
            task="Evaluate the security of AWS Bedrock infrastructure",
            agent_group={
                "research-agent": "Current threats and vulnerabilities",
                "analyzer-agent": "Risk assessment",
                "writer-agent": "Documentation review",
            },
        )
        print(f"\nParallel Results: {json.dumps(result['parallel_results'], indent=2)}")
    except Exception as e:
        print(f"Error in parallel workflow: {e}")

    # Example 3: Voting Consensus
    print("\n" + "=" * 60)
    print("EXAMPLE 3: VOTING CONSENSUS")
    print("=" * 60)

    try:
        result = orchestrator.voting_consensus(
            proposition="AWS Bedrock is the best choice for our agent infrastructure",
            voting_agents=["research-agent", "analyzer-agent"],
            threshold=0.5,
        )
        print(f"\nConsensus Result: {result['decision']}")
        print(f"Approval Ratio: {result['approval_ratio']:.0%}")
    except Exception as e:
        print(f"Error in voting consensus: {e}")

    # Print final summary
    orchestrator.print_summary()


if __name__ == "__main__":
    main()
