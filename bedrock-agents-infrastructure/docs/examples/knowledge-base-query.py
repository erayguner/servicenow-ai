#!/usr/bin/env python3
"""
Knowledge Base Query Example

This example demonstrates how to interact with Bedrock Knowledge Bases
for retrieval-augmented generation (RAG) workflows.
"""

import boto3
import json
from typing import List, Dict, Any
import os
from pathlib import Path


class KnowledgeBaseClient:
    """Client for Bedrock Knowledge Base operations."""

    def __init__(self, knowledge_base_id: str, region: str = "us-east-1"):
        """
        Initialize knowledge base client.

        Args:
            knowledge_base_id: ID of the knowledge base
            region: AWS region
        """
        self.knowledge_base_id = knowledge_base_id
        self.client = boto3.client("bedrock-agent-runtime", region_name=region)
        self.bedrock_agent = boto3.client("bedrock-agent", region_name=region)

    def retrieve_documents(
        self, query: str, max_results: int = 5
    ) -> List[Dict[str, Any]]:
        """
        Retrieve documents from knowledge base.

        Args:
            query: Search query
            max_results: Maximum number of results to return

        Returns:
            List of retrieved documents with metadata
        """
        print(f"\nRetrieving documents for: '{query}'")
        print(f"Max results: {max_results}")

        try:
            response = self.client.retrieve(
                knowledgeBaseId=self.knowledge_base_id,
                retrievalQuery={"text": query},
                retrievalConfiguration={
                    "vectorSearchConfiguration": {
                        "numberOfResults": max_results,
                        "overrideSearchType": "HYBRID",  # Hybrid search
                    }
                },
            )

            results = []
            for i, result in enumerate(response.get("retrievalResults", []), 1):
                doc_info = {
                    "rank": i,
                    "content": result["content"]["text"],
                    "score": result.get("score", 0),
                    "location": result.get("location", {})
                    .get("s3Location", {})
                    .get("uri", "Unknown"),
                    "metadata": result.get("metadata", {}),
                }
                results.append(doc_info)

                print(f"\n[Document {i}]")
                print(f"  Score: {doc_info['score']:.4f}")
                print(f"  Location: {doc_info['location']}")
                print(f"  Content: {doc_info['content'][:200]}...")

            return results

        except Exception as e:
            print(f"Error retrieving documents: {e}")
            return []

    def retrieve_with_agent(self, agent_id: str, query: str) -> str:
        """
        Use an agent to query the knowledge base.

        The agent can interpret the query and retrieve relevant documents
        automatically.

        Args:
            agent_id: Agent ID that has knowledge base action group
            query: User query

        Returns:
            Agent's response with retrieved information
        """
        print(f"\nQuerying with agent: {agent_id}")
        print(f"Query: {query}")

        bedrock_runtime = boto3.client("bedrock-agent-runtime")

        response = bedrock_runtime.invoke_agent(
            agentId=agent_id,
            agentAliasId="PROD",
            sessionId="kb-query-session",
            inputText=query,
        )

        print(f"Agent Response: {response['output']}")
        return response["output"]

    def upload_documents(
        self, document_paths: List[str], data_source_id: str
    ) -> Dict[str, Any]:
        """
        Upload documents to knowledge base.

        Args:
            document_paths: List of file paths to upload
            data_source_id: ID of the data source

        Returns:
            Ingestion job status
        """
        print(f"\nUploading {len(document_paths)} documents")

        # Upload to S3 first
        s3 = boto3.client("s3")
        bucket_name = f"knowledge-base-{self.knowledge_base_id}"

        for doc_path in document_paths:
            file_name = Path(doc_path).name
            print(f"Uploading: {file_name}")

            try:
                s3.upload_file(doc_path, bucket_name, f"documents/{file_name}")
                print(f"  Success: s3://{bucket_name}/documents/{file_name}")
            except Exception as e:
                print(f"  Error: {e}")

        # Start ingestion job
        print("\nStarting ingestion job...")

        try:
            response = self.bedrock_agent.start_ingestion_job(
                knowledgeBaseId=self.knowledge_base_id, dataSourceId=data_source_id
            )

            ingestion_job = response["ingestionJob"]

            return {
                "job_id": ingestion_job["ingestionJobId"],
                "status": ingestion_job["status"],
                "started_at": ingestion_job.get("createdAt", ""),
            }

        except Exception as e:
            print(f"Error starting ingestion: {e}")
            return {}

    def get_ingestion_status(
        self, data_source_id: str, ingestion_job_id: str
    ) -> Dict[str, Any]:
        """
        Get status of an ingestion job.

        Args:
            data_source_id: Data source ID
            ingestion_job_id: Ingestion job ID

        Returns:
            Job status information
        """
        print(f"\nChecking ingestion status...")

        try:
            response = self.bedrock_agent.get_ingestion_job(
                knowledgeBaseId=self.knowledge_base_id,
                dataSourceId=data_source_id,
                ingestionJobId=ingestion_job_id,
            )

            job = response["ingestionJob"]

            status_info = {
                "status": job["status"],
                "document_count": job.get("statistics", {}).get(
                    "numberOfDocumentsScanned", 0
                ),
                "failed_count": job.get("statistics", {}).get(
                    "numberOfDocumentsFailed", 0
                ),
                "success_count": job.get("statistics", {}).get(
                    "numberOfDocumentsIndexed", 0
                ),
            }

            print(f"Status: {status_info['status']}")
            print(f"Documents processed: {status_info['document_count']}")
            print(f"Successfully indexed: {status_info['success_count']}")
            print(f"Failed: {status_info['failed_count']}")

            return status_info

        except Exception as e:
            print(f"Error getting ingestion status: {e}")
            return {}

    def search_with_filters(
        self, query: str, metadata_filters: Dict[str, Any] = None, max_results: int = 5
    ) -> List[Dict[str, Any]]:
        """
        Retrieve documents with metadata filters.

        Args:
            query: Search query
            metadata_filters: Filters to apply (e.g., {"source": "manual", "type": "policy"})
            max_results: Maximum results

        Returns:
            Filtered retrieval results
        """
        print(f"\nSearching with filters")
        print(f"Query: {query}")
        print(f"Filters: {metadata_filters}")

        try:
            # Note: Filter syntax depends on your knowledge base configuration
            response = self.client.retrieve(
                knowledgeBaseId=self.knowledge_base_id,
                retrievalQuery={"text": query},
                retrievalConfiguration={
                    "vectorSearchConfiguration": {
                        "numberOfResults": max_results,
                        "filter": (
                            {
                                "equals": {
                                    "key": "metadata.source",
                                    "value": metadata_filters.get("source", ""),
                                }
                            }
                            if metadata_filters
                            else None
                        ),
                    }
                },
            )

            results = []
            for result in response.get("retrievalResults", []):
                results.append(
                    {
                        "content": result["content"]["text"],
                        "score": result.get("score", 0),
                        "metadata": result.get("metadata", {}),
                    }
                )

            print(f"Found {len(results)} matching documents")
            return results

        except Exception as e:
            print(f"Error in filtered search: {e}")
            return []

    def semantic_search(
        self, query: str, similarity_threshold: float = 0.7
    ) -> List[Dict[str, Any]]:
        """
        Perform semantic search for conceptually similar documents.

        Args:
            query: Natural language query
            similarity_threshold: Minimum similarity score (0.0 to 1.0)

        Returns:
            Semantically similar documents
        """
        print(f"\nPerforming semantic search")
        print(f"Query: {query}")
        print(f"Similarity threshold: {similarity_threshold}")

        results = self.retrieve_documents(query, max_results=10)

        # Filter by threshold
        filtered = [r for r in results if r["score"] >= similarity_threshold]

        print(f"Found {len(filtered)} documents above threshold")
        return filtered


def demonstrate_rag_workflow():
    """
    Demonstrate a complete RAG (Retrieval-Augmented Generation) workflow.

    This shows how to:
    1. Retrieve documents from knowledge base
    2. Use retrieved docs with agent for better responses
    """
    print("=" * 60)
    print("RAG WORKFLOW DEMONSTRATION")
    print("=" * 60)

    # Initialize client
    kb_client = KnowledgeBaseClient(knowledge_base_id="YOUR_KNOWLEDGE_BASE_ID")

    # Step 1: Retrieve relevant documents
    query = "How do I create a ServiceNow incident through API?"
    documents = kb_client.retrieve_documents(query=query, max_results=3)

    if documents:
        # Step 2: Format retrieved context
        context = "\n\n".join(
            [f"Document {doc['rank']}:\n{doc['content']}" for doc in documents]
        )

        # Step 3: Send to agent with context
        agent_query = f"""Based on the following documents, {query}

Context:
{context}

Please provide a comprehensive answer based on these documents."""

        print(f"\nSending context-enhanced query to agent...")
        print(f"Context length: {len(context)} characters")

        # In production, invoke your agent with this enhanced query
        # response = bedrock_runtime.invoke_agent(...)


def demonstrate_chunk_search():
    """
    Demonstrate retrieving specific chunks/passages from documents.
    """
    print("\n" + "=" * 60)
    print("CHUNK/PASSAGE RETRIEVAL")
    print("=" * 60)

    kb_client = KnowledgeBaseClient(knowledge_base_id="YOUR_KNOWLEDGE_BASE_ID")

    # Search for specific information
    queries = [
        "ServiceNow API authentication",
        "Incident creation workflow",
        "CMDB configuration",
        "Change management process",
    ]

    results = {}
    for query in queries:
        print(f"\n--- Searching: {query} ---")
        docs = kb_client.retrieve_documents(query, max_results=2)
        results[query] = docs

    # Aggregate results
    print(f"\n{'-'*60}")
    print(f"Total queries: {len(queries)}")
    print(
        f"Total unique documents: {len(set(str(d) for docs in results.values() for d in docs))}"
    )


def demonstrate_knowledge_update():
    """
    Demonstrate updating knowledge base with new documents.
    """
    print("\n" + "=" * 60)
    print("KNOWLEDGE BASE UPDATE")
    print("=" * 60)

    kb_client = KnowledgeBaseClient(knowledge_base_id="YOUR_KNOWLEDGE_BASE_ID")

    # Create sample documents
    sample_docs = ["document1.pdf", "document2.txt", "document3.md"]

    # Upload documents
    job_info = kb_client.upload_documents(
        document_paths=sample_docs, data_source_id="YOUR_DATA_SOURCE_ID"
    )

    if job_info:
        print(f"Ingestion job started: {job_info['job_id']}")
        print(f"Status: {job_info['status']}")

        # Check status
        import time

        time.sleep(5)

        status = kb_client.get_ingestion_status(
            data_source_id="YOUR_DATA_SOURCE_ID", ingestion_job_id=job_info["job_id"]
        )


def main():
    """Main function demonstrating knowledge base usage."""

    print("\n" + "=" * 60)
    print("BEDROCK KNOWLEDGE BASE EXAMPLES")
    print("=" * 60)

    # Example 1: Simple retrieval
    print("\n" + "=" * 60)
    print("EXAMPLE 1: SIMPLE DOCUMENT RETRIEVAL")
    print("=" * 60)

    kb_client = KnowledgeBaseClient(knowledge_base_id="YOUR_KNOWLEDGE_BASE_ID")

    try:
        documents = kb_client.retrieve_documents(
            query="How to reset password", max_results=3
        )

        if documents:
            print(f"\nRetrieved {len(documents)} documents")
            print(f"Top result score: {documents[0]['score']:.4f}")

    except Exception as e:
        print(f"Error: {e}")

    # Example 2: Semantic search
    print("\n" + "=" * 60)
    print("EXAMPLE 2: SEMANTIC SEARCH")
    print("=" * 60)

    try:
        results = kb_client.semantic_search(
            query="User account management", similarity_threshold=0.7
        )
        print(f"Found {len(results)} semantically similar documents")

    except Exception as e:
        print(f"Error: {e}")

    # Example 3: RAG workflow
    print("\n" + "=" * 60)
    print("EXAMPLE 3: RAG WORKFLOW")
    print("=" * 60)

    try:
        demonstrate_rag_workflow()
    except Exception as e:
        print(f"Error in RAG workflow: {e}")


if __name__ == "__main__":
    main()
